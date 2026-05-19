// Parlance/Core/Networking/APIClient.swift
import Foundation
import Supabase

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

nonisolated struct Endpoint<Request: Encodable, Response> {
    let path: String
    let method: HTTPMethod
    let request: Request?
    let timeout: TimeInterval
    let encode: (Request) throws -> Data
    let decode: (Data) throws -> Response

    init(
        path: String,
        method: HTTPMethod = .post,
        request: Request?,
        timeout: TimeInterval = 30,
        encode: @escaping (Request) throws -> Data = { try JSONEncoder().encode($0) },
        decode: @escaping (Data) throws -> Response
    ) {
        self.path = path
        self.method = method
        self.request = request
        self.timeout = timeout
        self.encode = encode
        self.decode = decode
    }
}

extension Endpoint where Response: Decodable {
    nonisolated static func json(
        path: String,
        method: HTTPMethod = .post,
        request: Request?,
        timeout: TimeInterval = 30,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) -> Endpoint<Request, Response> {
        Endpoint(
            path: path,
            method: method,
            request: request,
            timeout: timeout,
            encode: { try encoder.encode($0) },
            decode: { try decoder.decode(Response.self, from: $0) }
        )
    }
}

enum APIError: Error {
    case unauthorized
    case rateLimited
    case server(status: Int, body: String?)
    case decode(underlying: Error)
    case transport(underlying: Error)
    case offline
}

actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = AppConstants.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Req, Res>(_ endpoint: Endpoint<Req, Res>) async throws -> Res {
        let accessToken: String
        do {
            let supabaseClient = await MainActor.run { SupabaseManager.shared.client }
            accessToken = try await supabaseClient.auth.session.accessToken
        } catch {
            throw APIError.unauthorized
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = endpoint.timeout

        if let body = endpoint.request {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try endpoint.encode(body)
            } catch {
                throw APIError.decode(underlying: error)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[APIClient] transport error for \(endpoint.path): \(error)")
            #endif
            throw APIError.transport(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(status: -1, body: nil)
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try endpoint.decode(data)
            } catch {
                throw APIError.decode(underlying: error)
            }
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.server(status: http.statusCode, body: body)
        }
    }
}

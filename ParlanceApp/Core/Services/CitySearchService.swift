import Foundation
import MapKit
import Combine

struct CitySuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String

    fileprivate let completion: MKLocalSearchCompletion

    static func == (lhs: CitySuggestion, rhs: CitySuggestion) -> Bool {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }
}

struct CityResult: Equatable {
    let city: String
    let country: String

    var formatted: String { "\(city), \(country)" }
}

@MainActor
final class CitySearchService: NSObject, ObservableObject {
    @Published private(set) var suggestions: [CitySuggestion] = []
    @Published private(set) var isSearching = false

    private let completer: MKLocalSearchCompleter
    private var debounceTask: Task<Void, Never>?

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.resultTypes = [.address]
        completer.delegate = self
    }

    func search(_ query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            isSearching = false
            return
        }
        isSearching = true
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.completer.queryFragment = trimmed
            }
        }
    }

    func clear() {
        debounceTask?.cancel()
        completer.queryFragment = ""
        suggestions = []
        isSearching = false
    }

    func resolve(_ suggestion: CitySuggestion) async -> CityResult? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let placemark = response.mapItems.first?.placemark else { return nil }
            guard let city = placemark.locality ?? placemark.subAdministrativeArea,
                  let country = placemark.country else { return nil }
            return CityResult(city: city, country: country)
        } catch {
            return nil
        }
    }
}

extension CitySearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.suggestions = results
                .filter { Self.looksLikeCity($0) }
                .prefix(8)
                .map { CitySuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.suggestions = []
            self?.isSearching = false
        }
    }

    // MKLocalSearchCompleter returns addresses, POIs, and cities. We want only
    // city-like results: the title should be the place name and the subtitle
    // should not contain a street number or POI category.
    private static func looksLikeCity(_ completion: MKLocalSearchCompletion) -> Bool {
        let title = completion.title
        let subtitle = completion.subtitle
        if title.isEmpty { return false }
        // Heuristic: titles with a leading digit are usually street addresses.
        if let first = title.first, first.isNumber { return false }
        // Subtitle being a search-suggestion placeholder ("Search Nearby") isn't useful.
        if subtitle.lowercased().contains("search nearby") { return false }
        return true
    }
}

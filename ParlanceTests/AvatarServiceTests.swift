import Testing
import Foundation
import UIKit
@testable import Parlance

@Suite("AvatarService")
struct AvatarServiceTests {

    @Test("objectPath uses {userId}/avatar.jpg layout")
    func objectPathFormat() {
        let path = AvatarService.objectPath(for: "abc-123")
        #expect(path == "abc-123/avatar.jpg")
    }

    @Test("publicURL appends ?v= cache-buster from updatedAt epoch")
    func publicURLCacheBuster() {
        let updated = Date(timeIntervalSince1970: 1_700_000_000)
        let url = AvatarService.cacheBustedURL(
            base: URL(string: "https://example.supabase.co/storage/v1/object/public/avatars/abc/avatar.jpg")!,
            updatedAt: updated
        )
        #expect(url.absoluteString.hasSuffix("?v=1700000000"))
    }

    @Test("publicURL with nil updatedAt returns base URL unchanged")
    func publicURLNoCacheBuster() {
        let base = URL(string: "https://example.supabase.co/avatars/abc/avatar.jpg")!
        let url = AvatarService.cacheBustedURL(base: base, updatedAt: nil)
        #expect(url == base)
    }

    @Test("resizeForUpload produces a JPEG <=120KB and 512x512 max")
    func resizeForUploadShrinksLargeImage() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 3000)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 3000))
        }
        let bigData = big.pngData()!
        let resized = try AvatarService.resizeForUpload(bigData)
        #expect(resized.count < 120_000)
        let resizedImage = UIImage(data: resized)!
        #expect(resizedImage.size.width <= 512 && resizedImage.size.height <= 512)
    }
}

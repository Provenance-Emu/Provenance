import SwiftUI

actor ImageCache {
    static let shared = ImageCache()
    private var cache: [URL: Image] = [:]
    private let maxCachedImages = 50

    func image(for url: URL) -> Image? {
        cache[url]
    }

    func setImage(_ image: Image, for url: URL) {
        cache[url] = image
        cleanupCache()
    }

    private func cleanupCache() {
        if cache.count > maxCachedImages {
            let keysToRemove = Array(cache.keys.dropFirst(maxCachedImages))
            keysToRemove.forEach { cache.removeValue(forKey: $0) }
        }
    }
}

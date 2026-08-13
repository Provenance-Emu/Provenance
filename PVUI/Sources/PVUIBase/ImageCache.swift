import SwiftUI

/// Small LRU cache of SwiftUI `Image` values for the artwork-search preview grid.
///
/// `Image` is a struct, so this cannot use `NSCache`/``ImageMemoryCache``.
/// Instead it keeps an explicit access order — the previous implementation
/// trimmed with `Array(cache.keys.dropFirst(maxCachedImages))`, and because
/// `Dictionary.keys` has no defined order that evicted arbitrary entries rather
/// than the least recently used ones.
///
/// Callers are responsible for downsampling before inserting; see
/// `ArtworkDownsampler`.
actor ImageCache {
    static let shared = ImageCache()

    private var cache: [URL: Image] = [:]
    /// Least-recently-used first.
    private var accessOrder: [URL] = []
    private let maxCachedImages = 50

    func image(for url: URL) -> Image? {
        guard let image = cache[url] else { return nil }
        touch(url)
        return image
    }

    func setImage(_ image: Image, for url: URL) {
        cache[url] = image
        touch(url)
        evictIfNeeded()
    }

    private func touch(_ url: URL) {
        accessOrder.removeAll { $0 == url }
        accessOrder.append(url)
    }

    private func evictIfNeeded() {
        while cache.count > maxCachedImages, let oldest = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }
}

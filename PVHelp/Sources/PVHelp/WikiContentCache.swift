import Foundation
import PVLogging

public final class WikiContentCache: @unchecked Sendable {
    private let cacheDirectory: URL
    private nonisolated(unsafe) let fileManager = FileManager.default

    public init() {
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDir.appendingPathComponent(WikiConstants.cacheDirectoryName)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Page Content Cache (Disk)

    public func cachedPage(for path: String) -> String? {
        let fileURL = pageFileURL(for: path)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        return content
    }

    public func cachePage(_ content: String, for path: String) {
        let fileURL = pageFileURL(for: path)
        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? content.data(using: .utf8)?.write(to: fileURL)
        setTimestamp(for: pageCacheKey(path))
    }

    public func isPageCacheValid(for path: String) -> Bool {
        isTimestampValid(for: pageCacheKey(path))
    }

    // MARK: - Navigation Tree Cache (UserDefaults)

    public func cachedNavigationTree() -> WikiNavigationTree? {
        guard let data = UserDefaults.standard.data(forKey: WikiConstants.navigationCacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WikiNavigationTree.self, from: data)
    }

    public func cacheNavigationTree(_ tree: WikiNavigationTree) {
        guard let data = try? JSONEncoder().encode(tree) else { return }
        UserDefaults.standard.set(data, forKey: WikiConstants.navigationCacheKey)
        setTimestamp(for: WikiConstants.navigationTimestampKey)
    }

    public func isNavigationCacheValid() -> Bool {
        isTimestampValid(for: WikiConstants.navigationTimestampKey)
    }

    // MARK: - Clear

    public func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: WikiConstants.navigationCacheKey)
        UserDefaults.standard.removeObject(forKey: WikiConstants.navigationTimestampKey)
        DLOG("WikiContentCache: cleared all caches")
    }

    // MARK: - Private

    private func pageFileURL(for path: String) -> URL {
        cacheDirectory.appendingPathComponent(path)
    }

    private func pageCacheKey(_ path: String) -> String {
        "PVHelp_page_\(path)"
    }

    private func setTimestamp(for key: String) {
        UserDefaults.standard.set(Date(), forKey: key)
    }

    private func isTimestampValid(for key: String) -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: key) as? Date else {
            return false
        }
        return Date().timeIntervalSince(timestamp) < WikiConstants.cacheTTL
    }
}

import Foundation
import PVLogging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class WikiContentProvider: Sendable {
    public let cache = WikiContentCache()

    public init() {}

    // MARK: - Navigation Tree

    /// Load the navigation tree with cache-first strategy.
    /// Returns cached tree immediately if available; refreshes in background if TTL expired.
    public func loadNavigationTree() async -> WikiNavigationTree {
        // Try cache first — re-apply filter in case blocklist has changed since caching
        if let cached = cache.cachedNavigationTree()?.appStoreFiltered() {
            if !cache.isNavigationCacheValid() {
                // Refresh in background
                Task { await refreshNavigationTree() }
            }
            return cached
        }

        // Try network
        if let tree = await refreshNavigationTree() {
            return tree
        }

        // Fall back to bundled SUMMARY.md
        return loadBundledNavigationTree()
    }

    @discardableResult
    private func refreshNavigationTree() async -> WikiNavigationTree? {
        do {
            let content = try await fetchRawContent(WikiConstants.summaryFileName)
            let tree = WikiNavigationTree.parse(markdown: content)
            cache.cacheNavigationTree(tree)
            DLOG("WikiContentProvider: refreshed navigation tree (\(tree.sections.count) sections)")
            return tree
        } catch {
            DLOG("WikiContentProvider: failed to refresh navigation tree: \(error)")
            return nil
        }
    }

    private func loadBundledNavigationTree() -> WikiNavigationTree {
        guard let url = Bundle.module.url(forResource: "SUMMARY", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            DLOG("WikiContentProvider: bundled SUMMARY.md not found")
            return WikiNavigationTree(sections: [])
        }
        let tree = WikiNavigationTree.parse(markdown: content)
        DLOG("WikiContentProvider: loaded bundled navigation tree (\(tree.sections.count) sections)")
        return tree
    }

    // MARK: - Page Content

    /// Load a wiki page with cache-first strategy and GitBook preprocessing.
    public func loadPage(path: String, title: String) async -> WikiPage {
        // Try cache first
        if let cached = cache.cachedPage(for: path) {
            if !cache.isPageCacheValid(for: path) {
                // Refresh in background
                Task { await refreshPage(path: path) }
            }
            let processed = GitBookPreprocessor.process(cached)
            return WikiPage(path: path, title: title, content: processed)
        }

        // Try network
        if let content = await refreshPage(path: path) {
            let processed = GitBookPreprocessor.process(content)
            return WikiPage(path: path, title: title, content: processed)
        }

        // Offline fallback
        return WikiPage(path: path, title: title, content: "**Offline** — This page is not yet cached. Connect to the internet and try again.")
    }

    @discardableResult
    private func refreshPage(path: String) async -> String? {
        do {
            let content = try await fetchRawContent(path)
            cache.cachePage(content, for: path)
            return content
        } catch {
            DLOG("WikiContentProvider: failed to fetch page '\(path)': \(error)")
            return nil
        }
    }

    // MARK: - Network

    private func fetchRawContent(_ path: String) async throws -> String {
        let url = WikiConstants.rawURL(for: path)
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw WikiContentError.httpError(httpResponse.statusCode)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw WikiContentError.invalidEncoding
        }

        return content
    }

    /// Clear all cached content and force reload.
    public func clearCache() {
        cache.clearAll()
    }
}

public enum WikiContentError: Error, LocalizedError {
    case httpError(Int)
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP error \(code)"
        case .invalidEncoding: return "Invalid text encoding"
        }
    }
}

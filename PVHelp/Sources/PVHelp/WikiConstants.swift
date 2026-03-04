import Foundation

public enum WikiConstants {
    public static let baseURL = URL(string: "https://raw.githubusercontent.com/Provenance-EMU/wiki/master/")!
    public static let webBaseURL = URL(string: "https://wiki.provenance-emu.com/")!
    public static let cacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours
    public static let cacheDirectoryName = "PVHelp"
    public static let navigationCacheKey = "PVHelp_NavigationTree"
    public static let navigationTimestampKey = "PVHelp_NavigationTimestamp"
    public static let summaryFileName = "SUMMARY.md"

    public static func rawURL(for path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    public static func webURL(for path: String) -> URL {
        let webPath = path
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: "/README", with: "")
        return webBaseURL.appendingPathComponent(webPath)
    }
}

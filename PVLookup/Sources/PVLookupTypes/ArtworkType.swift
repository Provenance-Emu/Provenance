/// Represents different types of artwork
public struct ArtworkType: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Box/Cover art front
    public static let boxFront     = ArtworkType(rawValue: 1 << 0)
    /// Box/Cover art back
    public static let boxBack      = ArtworkType(rawValue: 1 << 1)
    /// Game manual
    public static let manual       = ArtworkType(rawValue: 1 << 2)
    /// In-game screenshot
    public static let screenshot   = ArtworkType(rawValue: 1 << 3)
    /// Title screen
    public static let titleScreen  = ArtworkType(rawValue: 1 << 4)
    /// Fan art
    public static let fanArt      = ArtworkType(rawValue: 1 << 5)
    /// Banner artwork
    public static let banner      = ArtworkType(rawValue: 1 << 6)
    /// Clear logo
    public static let clearLogo   = ArtworkType(rawValue: 1 << 7)
    /// Other artwork types
    public static let other       = ArtworkType(rawValue: 1 << 8)

    /// Default set of artwork types
    public static let defaults: ArtworkType = [.boxFront, .titleScreen, .screenshot]
}


// Helper for display names
public extension ArtworkType {
    var displayName: String {
        switch self {
        case .boxFront: return "Box Front"
        case .boxBack: return "Box Back"
        case .screenshot: return "Screenshot"
        case .titleScreen: return "Title Screen"
        case .clearLogo: return "Clear Logo"
        case .banner: return "Banner"
        case .fanArt: return "Fan Art"
        case .manual: return "Manual"
        case .other: return "Other"
        default: return "Unknown"
        }
    }
}

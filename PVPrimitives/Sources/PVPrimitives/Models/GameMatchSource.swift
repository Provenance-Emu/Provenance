import Foundation

/// Tracks how a game's metadata was populated
@objc public enum GameMatchSource: Int, Codable, Sendable {
    /// Game has never been successfully matched (default)
    case none = 0
    /// Matched via MD5/CRC hash lookup
    case md5 = 1
    /// Matched via name-based lookup after user rename
    case nameLookup = 2
    /// User manually imported/set metadata
    case userImported = 3
    /// Metadata manually set field-by-field by the user
    case manual = 4
}

extension GameMatchSource: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none: return "none"
        case .md5: return "md5"
        case .nameLookup: return "nameLookup"
        case .userImported: return "userImported"
        case .manual: return "manual"
        }
    }
}

/// Bitmask of game metadata fields that have been explicitly set by the user
public struct GameCustomizedFields: OptionSet, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let title         = GameCustomizedFields(rawValue: 1 << 0)
    public static let artwork       = GameCustomizedFields(rawValue: 1 << 1)
    public static let description   = GameCustomizedFields(rawValue: 1 << 2)
    public static let developer     = GameCustomizedFields(rawValue: 1 << 3)
    public static let publisher     = GameCustomizedFields(rawValue: 1 << 4)
    public static let genres        = GameCustomizedFields(rawValue: 1 << 5)
    public static let releaseDate   = GameCustomizedFields(rawValue: 1 << 6)
    public static let rating        = GameCustomizedFields(rawValue: 1 << 7)
    public static let boxBackArt    = GameCustomizedFields(rawValue: 1 << 8)
    public static let referenceURL  = GameCustomizedFields(rawValue: 1 << 9)
}

public struct OverlayLayoutFile: Codable, Equatable, Sendable {
    public var version: Int
    public var layouts: [String: [String: GroupOverride]]
    public var games: [String: [String: [String: GroupOverride]]]
    public static let currentVersion = 1
    public static let empty = OverlayLayoutFile(version: currentVersion, layouts: [:], games: [:])

    public func overrides(for key: String, gameMD5: String?) -> OverlayLayoutOverrides {
        if let md5 = gameMD5, let groups = games[md5]?[key] { return OverlayLayoutOverrides(groups: groups) }
        if let groups = layouts[key] { return OverlayLayoutOverrides(groups: groups) }
        return .empty
    }
}

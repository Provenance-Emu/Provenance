import Foundation

/// What is known about a game's network play beyond "its core carries netplay".
///
/// A hint is advice shown beside a game. It never hides a game and never blocks hosting or
/// joining: a game with no hint is `unknown` and is offered like any other.
public enum NetplayGameHint: String, Codable, CaseIterable, Sendable {
    case unknown, works, reportedBroken

    /// A short label for the game's card, nil when there is nothing to say.
    public var label: String? {
        switch self {
        case .unknown: return nil
        case .works: return "Reported working"
        case .reportedBroken: return "Reported broken"
        }
    }
}

/// The game and core a hint is about.
public struct NetplayGameIdentity: Hashable, Sendable {
    public var md5: String
    public var systemIdentifier: String
    public var coreIdentifier: String

    public init(md5: String, systemIdentifier: String, coreIdentifier: String) {
        self.md5 = md5
        self.systemIdentifier = systemIdentifier
        self.coreIdentifier = coreIdentifier
    }
}

/// Something that knows hints: the seam for a shared community database.
public protocol NetplayGameHintSource: Sendable {
    func hint(for game: NetplayGameIdentity) -> NetplayGameHint
}

/// Where the app asks for a game's hint. No source ships yet, so every game is `unknown`.
@MainActor
public enum NetplayGameHints {
    /// Install a source here (a community database, once one exists).
    public static var source: (any NetplayGameHintSource)?

    public static func hint(for game: NetplayGameIdentity) -> NetplayGameHint {
        source?.hint(for: game) ?? .unknown
    }
}

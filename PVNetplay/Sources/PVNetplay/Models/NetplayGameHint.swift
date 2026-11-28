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
    /// The library MD5 of the ROM (`PVGame.md5Hash`).
    public var md5: String
    /// The game's system, e.g. "com.provenance.gba".
    public var systemIdentifier: String
    /// The core the game would run on. A hint for one core says nothing about another.
    public var coreIdentifier: String

    /// Names a game as run on one core.
    public init(md5: String, systemIdentifier: String, coreIdentifier: String) {
        self.md5 = md5
        self.systemIdentifier = systemIdentifier
        self.coreIdentifier = coreIdentifier
    }
}

/// Something that knows hints: the seam for a shared community database.
public protocol NetplayGameHintSource: Sendable {
    /// What this source knows about `game` on that core; `unknown` when it knows nothing.
    /// Called on the main actor while lists are drawn, so answer from memory without blocking.
    func hint(for game: NetplayGameIdentity) -> NetplayGameHint
}

/// Where the app asks for a game's hint. No source ships yet, so every game is `unknown`.
@MainActor
public enum NetplayGameHints {
    /// Install a source here (a community database, once one exists).
    public static var source: (any NetplayGameHintSource)?

    /// The installed source's hint for `game`, or `unknown` when there is no source.
    public static func hint(for game: NetplayGameIdentity) -> NetplayGameHint {
        source?.hint(for: game) ?? .unknown
    }
}

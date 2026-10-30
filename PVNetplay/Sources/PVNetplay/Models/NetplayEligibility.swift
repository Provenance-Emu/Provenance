import Foundation

/// How players participate. A one-player-per-device game can still support linked play.
public enum NetplayPlayMode: String, Codable, CaseIterable, Sendable {
    case sharedConsole, alternating, linkCable, localWireless, nativeNetwork

    public var title: String {
        switch self {
        case .sharedConsole: return "Shared console"
        case .alternating: return "Alternating turns"
        case .linkCable: return "Link cable"
        case .localWireless: return "Local wireless"
        case .nativeNetwork: return "Native network"
        }
    }

    public var isSharedConsole: Bool { self == .sharedConsole || self == .alternating }
}

/// Multiplayer facts, independent of whether an emulator can carry that mode online.
public struct NetplayMultiplayerMetadata: Codable, Equatable, Sendable {
    public struct Mode: Codable, Equatable, Sendable {
        public var kind: NetplayPlayMode
        public var maxPlayers: Int
        public init(_ kind: NetplayPlayMode, maxPlayers: Int) {
            self.kind = kind
            self.maxPlayers = maxPlayers
        }
    }

    public enum Source: String, Codable, Sendable { case gameTDB, userConfirmed }
    public var modes: [Mode]
    /// True only when the source establishes that no useful multiplayer mode exists.
    public var singlePlayerOnly: Bool
    public var source: Source
    public var reference: String

    public init(modes: [Mode], singlePlayerOnly: Bool = false, source: Source, reference: String) {
        self.modes = modes
        self.singlePlayerOnly = singlePlayerOnly
        self.source = source
        self.reference = reference
    }
}

/// A platform-specific, installed core capability supplied by the host application.
public struct NetplayCoreSupport: Hashable, Sendable {
    public let coreIdentifier: String
    public let coreVersion: String
    public let modes: Set<NetplayPlayMode>
    public let maxPlayers: Int
    public let supportsSpectators: Bool
    public let supportsFrameDelay: Bool

    public init(coreIdentifier: String, modes: Set<NetplayPlayMode>, maxPlayers: Int,
                supportsSpectators: Bool = false, supportsFrameDelay: Bool = false, coreVersion: String = "") {
        self.coreIdentifier = coreIdentifier
        self.coreVersion = coreVersion
        self.modes = modes
        self.maxPlayers = maxPlayers
        self.supportsSpectators = supportsSpectators
        self.supportsFrameDelay = supportsFrameDelay
    }
}

public struct NetplayGameOption: Hashable, Sendable, Identifiable {
    public let core: NetplayCoreSupport
    public let mode: NetplayPlayMode
    public let maxPlayers: Int
    public var id: String { core.coreIdentifier + ":" + mode.rawValue }
}

public enum NetplayEligibility: Equatable, Sendable {
    case supported([NetplayGameOption])
    case unverified
    case unavailable(String)

    public var options: [NetplayGameOption] {
        if case .supported(let options) = self { return options }
        return []
    }

    /// Resolves a room only when its exact game, installed core/version and mode agree.
    public func joinOption(for room: NetplayRoom, gameMD5: String, systemIdentifier: String) -> NetplayGameOption? {
        guard !room.isFull, !room.coreIdentifier.isEmpty, !gameMD5.isEmpty,
              room.gameHash.caseInsensitiveCompare(gameMD5) == .orderedSame,
              room.systemIdentifier.isEmpty || room.systemIdentifier == systemIdentifier else { return nil }
        let matches = options.filter {
            $0.core.coreIdentifier == room.coreIdentifier && room.maxPlayers >= 2 && room.maxPlayers <= $0.maxPlayers
                && (room.coreVersion.isEmpty || room.coreVersion == $0.core.coreVersion)
                && (room.playMode == nil || room.playMode == $0.mode)
        }
        return matches.count == 1 ? matches.first : nil
    }

    /// Fail closed: core availability never substitutes for game-mode metadata.
    public static func evaluate(localFileAvailable: Bool, metadata: NetplayMultiplayerMetadata?, cores: [NetplayCoreSupport], hasUnverifiedCore: Bool = false) -> Self {
        guard localFileAvailable else { return .unavailable("Download the game first.") }
        guard let metadata else { return .unverified }
        guard !metadata.singlePlayerOnly else { return .unavailable("Single-player only.") }
        guard !metadata.modes.isEmpty else { return .unverified }
        let options = cores.flatMap { core in
            metadata.modes.compactMap { mode -> NetplayGameOption? in
                let limit = min(mode.maxPlayers, core.maxPlayers)
                guard core.modes.contains(mode.kind), limit >= 2 else { return nil }
                return NetplayGameOption(core: core, mode: mode.kind, maxPlayers: limit)
            }
        }
        if !options.isEmpty { return .supported(options) }
        return hasUnverifiedCore ? .unverified : .unavailable("No installed core supports this multiplayer mode.")
    }
}

public enum NetplayGameList: String, CaseIterable, Sendable {
    case suggested, allSupported, recent, favorites, unverified
    public var title: String {
        switch self {
        case .suggested: return "Suggested"
        case .allSupported: return "All supported"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .unverified: return "Unverified"
        }
    }
}

/// Value snapshots keep eligibility/ranking independent of Realm and UI threads.
public struct NetplayRankedGame: Sendable {
    public var id: String
    public var title: String
    public var system: String
    public var favorite: Bool
    public var lastPlayed: Date?
    public var hasJoinableRoom: Bool
    public var eligibility: NetplayEligibility

    public init(id: String, title: String, system: String, favorite: Bool, lastPlayed: Date?,
                hasJoinableRoom: Bool, eligibility: NetplayEligibility) {
        self.id = id
        self.title = title
        self.system = system
        self.favorite = favorite
        self.lastPlayed = lastPlayed
        self.hasJoinableRoom = hasJoinableRoom
        self.eligibility = eligibility
    }

    public static func select(_ games: [Self], list: NetplayGameList) -> [Self] {
        games.filter { game in
            if list == .unverified { return game.eligibility == .unverified }
            guard !game.eligibility.options.isEmpty else { return false }
            return (list != .recent || game.lastPlayed != nil) && (list != .favorites || game.favorite)
        }.sorted { lhs, rhs in
            if list == .suggested {
                if lhs.hasJoinableRoom != rhs.hasJoinableRoom { return lhs.hasJoinableRoom }
                if lhs.favorite != rhs.favorite { return lhs.favorite }
            }
            if list == .suggested || list == .recent, lhs.lastPlayed != rhs.lastPlayed {
                return (lhs.lastPlayed ?? .distantPast) > (rhs.lastPlayed ?? .distantPast)
            }
            let left = [lhs.title, lhs.system, lhs.id].map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
            let right = [rhs.title, rhs.system, rhs.id].map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
            return left.lexicographicallyPrecedes(right)
        }
    }
}

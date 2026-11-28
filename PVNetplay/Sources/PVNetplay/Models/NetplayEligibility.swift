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

extension NetplayCoreSupport {
    /// The mode a room on this core is advertised with: the first the core carries, in `NetplayPlayMode` order.
    public var primaryMode: NetplayPlayMode? { NetplayPlayMode.allCases.first(where: modes.contains) }
}

/// Whether a game can be played over the network on this device. Every game is assumed to
/// work: the only requirements are a local file and an installed core that carries netplay.
public enum NetplayEligibility: Equatable, Sendable {
    case available([NetplayGameOption])
    case unavailable(String)

    /// The fewest seats a room can have.
    public static let minimumPlayers = 2

    public var options: [NetplayGameOption] {
        if case .available(let options) = self { return options }
        return []
    }

    /// Resolves a room only when its exact game, installed core/version and mode agree.
    public func joinOption(for room: NetplayRoom, gameMD5: String, systemIdentifier: String) -> NetplayGameOption? {
        guard !room.isFull, !room.coreIdentifier.isEmpty, !gameMD5.isEmpty,
              room.gameHash.caseInsensitiveCompare(gameMD5) == .orderedSame,
              room.systemIdentifier.isEmpty || room.systemIdentifier == systemIdentifier else { return nil }
        return options.first {
            $0.core.coreIdentifier == room.coreIdentifier
                && room.maxPlayers >= Self.minimumPlayers && room.maxPlayers <= $0.maxPlayers
                && (room.coreVersion.isEmpty || room.coreVersion == $0.core.coreVersion)
                && (room.playMode.map($0.core.modes.contains) ?? true)
        }
    }

    /// One option per installed core that carries netplay. Nothing about the game itself is consulted.
    public static func evaluate(localFileAvailable: Bool, cores: [NetplayCoreSupport]) -> Self {
        guard localFileAvailable else { return .unavailable("Download the game first.") }
        let options = cores.compactMap { core -> NetplayGameOption? in
            guard let mode = core.primaryMode, core.maxPlayers >= minimumPlayers else { return nil }
            return NetplayGameOption(core: core, mode: mode, maxPlayers: core.maxPlayers)
        }
        return options.isEmpty ? .unavailable("No installed core supports network play for this system.") : .available(options)
    }
}

public enum NetplayGameList: String, CaseIterable, Sendable {
    case all, recent, favorites
    public var title: String {
        switch self {
        case .all: return "All Games"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        }
    }
}

/// Value snapshots keep ranking independent of Realm and UI threads.
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

    /// Games with an open room to join come first in every list; then Recent is last played
    /// first and the others are A to Z. Title, system and ROM identity break ties.
    public static func select(_ games: [Self], list: NetplayGameList) -> [Self] {
        games.filter { game in
            guard !game.eligibility.options.isEmpty else { return false }
            return (list != .recent || game.lastPlayed != nil) && (list != .favorites || game.favorite)
        }.sorted { lhs, rhs in
            if lhs.hasJoinableRoom != rhs.hasJoinableRoom { return lhs.hasJoinableRoom }
            if list == .recent, lhs.lastPlayed != rhs.lastPlayed {
                return (lhs.lastPlayed ?? .distantPast) > (rhs.lastPlayed ?? .distantPast)
            }
            return lhs.sortKey.lexicographicallyPrecedes(rhs.sortKey)
        }
    }

    private var sortKey: [String] {
        [title, system, id].map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
    }
}

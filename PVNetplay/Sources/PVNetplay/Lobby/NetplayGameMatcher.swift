//
//  NetplayGameMatcher.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// How a room's game was found in the local library.
public enum NetplayGameMatch<Game> {
    /// Same library MD5 as the host's.
    case sameFile(Game)
    /// Same serial and system, different file (another dump of the same disc).
    case sameSerial(Game)
    /// The library has no such game.
    case notInLibrary
    /// The host published neither hash nor serial, so the game can't be looked up.
    case unknown

    /// The matched game, if any.
    public var game: Game? {
        switch self {
        case .sameFile(let game), .sameSerial(let game): return game
        case .notInLibrary, .unknown: return nil
        }
    }
}

/// Finds a room's game in the local library.
///
/// Generic over the game type and driven by lookup closures, so it doesn't
/// depend on the database.
public enum NetplayGameMatcher {

    /// - Parameters:
    ///   - gameByMD5: Looks a game up by its library MD5, already uppercased.
    ///   - gameBySerial: Looks a game up by serial and system identifier.
    public static func match<Game>(
        _ room: NetplayRoom,
        gameByMD5: (String) -> Game?,
        gameBySerial: (_ serial: String, _ systemIdentifier: String) -> Game?
    ) -> NetplayGameMatch<Game> {
        let hash = room.gameHash.trimmingCharacters(in: .whitespaces).uppercased()
        let serial = room.gameSerial.trimmingCharacters(in: .whitespaces)
        let system = room.systemIdentifier.trimmingCharacters(in: .whitespaces)
        let canMatchSerial = !serial.isEmpty && !system.isEmpty

        guard !hash.isEmpty || canMatchSerial else { return .unknown }
        if !hash.isEmpty, let game = gameByMD5(hash) {
            return .sameFile(game)
        }
        if canMatchSerial, let game = gameBySerial(serial, system) {
            return .sameSerial(game)
        }
        return .notInLibrary
    }
}

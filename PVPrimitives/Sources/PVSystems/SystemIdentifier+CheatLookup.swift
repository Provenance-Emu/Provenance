// SystemIdentifier+CheatLookup.swift
// PVSystems
//
// Resolves which hardware `SystemIdentifier` to use for libretro `cht/` cheat lookup when
// denormalized game metadata says `RetroArch` (multi-system core) or the running core
// implies a concrete system (e.g. Flycast → Dreamcast, Virtual Jaguar → Atari Jaguar).

import Foundation

extension SystemIdentifier {

    /// Picks the effective system for libretro cheat database paths (`cht/<folder>/` on GitHub and in `libretro_cheats.sqlite`).
    ///
    /// - Parameters:
    ///   - gameSystemIdentifier: `PVGame.systemIdentifier` (may be `com.provenance.retroarch` for RetroArch-launched titles).
    ///   - linkedPVSystemIdentifier: `PVGame.system?.identifier` when the game is linked to a concrete `PVSystem`.
    ///   - coreIdentifier: Running core id (e.g. `flycast.libretro.framework`, `virtualjaguar.libretro.framework`, `com.provenance.core.jaguar`).
    /// - Returns: Resolved identifier, or `nil` when nothing usable is available.
    public static func cheatLookupResolvedIdentifier(
        gameSystemIdentifier: String,
        linkedPVSystemIdentifier: String?,
        coreIdentifier: String?
    ) -> SystemIdentifier? {
        let fromGame = SystemIdentifier(rawValue: gameSystemIdentifier)
        let fromLinked = linkedPVSystemIdentifier.flatMap { SystemIdentifier(rawValue: $0) }

        if let g = fromGame, g != .Unknown, g != .RetroArch {
            return g
        }
        if let s = fromLinked, s != .Unknown, s != .RetroArch {
            return s
        }
        if let cid = coreIdentifier?.lowercased() {
            if cid.contains("flycast") {
                return .Dreamcast
            }
            // Virtual Jaguar (libretro + Provenance core): `cht/Atari - Jaguar/`; linked PVSystem still wins (e.g. Jaguar CD).
            if cid.contains("virtualjaguar") || cid.contains("core.jaguar") {
                return .AtariJaguar
            }
        }
        if let g = fromGame, g != .Unknown {
            return g
        }
        return fromLinked
    }

    /// Libretro `cht/` directory name (e.g. `"Sega - Dreamcast"`) for cheat search, or `nil` when unknown.
    public static func cheatLookupLibretroFolderName(
        gameSystemIdentifier: String,
        linkedPVSystemIdentifier: String?,
        coreIdentifier: String?
    ) -> String? {
        guard let sid = cheatLookupResolvedIdentifier(
            gameSystemIdentifier: gameSystemIdentifier,
            linkedPVSystemIdentifier: linkedPVSystemIdentifier,
            coreIdentifier: coreIdentifier
        ) else { return nil }
        let name = sid.libretroCheatSystemName
        return name == "Unknown" ? nil : name
    }
}

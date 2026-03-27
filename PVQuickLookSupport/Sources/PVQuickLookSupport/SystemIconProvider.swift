//
//  SystemIconProvider.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Returns a system-specific SF Symbol name as a fallback icon when no
//  box-art is available.  Pure Foundation — no UIKit or AppKit imports.
//

import Foundation

/// Provides fallback SF Symbol names for emulator system identifiers.
///
/// When no artwork is cached for a game the extensions can call
/// `SystemIconProvider.sfSymbolName(forSystemIdentifier:)` to get an
/// appropriate symbol to display in the thumbnail or preview card.
public struct SystemIconProvider {

    // MARK: - Public API

    /// Returns an SF Symbol name appropriate for the given reverse-DNS system
    /// identifier (e.g. `"com.provenance.snes"`).
    ///
    /// The mapping groups systems by hardware category.  Unknown identifiers
    /// fall back to `"gamecontroller.fill"`.
    public static func sfSymbolName(forSystemIdentifier identifier: String) -> String {
        guard !identifier.isEmpty else { return Defaults.generic }
        let id = identifier.lowercased()

        switch true {
        // Handhelds — Nintendo
        case id.contains("gameboy") || id.contains(".gb") || id.contains(".gbc") || id.contains(".gba"):
            return "handheld.fill"
        case id.hasSuffix(".ds") || id.hasSuffix(".3ds") || id.contains("nintendo3ds") || id.contains("nintendods"):
            return "handheld.fill"
        // Handhelds — Sony
        case id.contains("psp") || id.contains("psv") || id.contains("vita"):
            return "handheld.fill"
        // Handhelds — Sega / Other
        // Note: WonderSwan uses short identifiers ".ws" / ".wsc" so we match by suffix
        // as well as the full "wonderswan" name.
        case id.contains("gamegear") || id.contains("lynx")
             || id.contains("wonderswan") || id.hasSuffix(".ws") || id.hasSuffix(".wsc"):
            return "handheld.fill"
        // Handhelds — generic
        case id.contains("portable") || id.contains("handheld") || id.contains("pocket"):
            return "handheld.fill"

        // Home consoles — Nintendo
        case id.contains("nes") && !id.contains("snes"):
            return "gamecontroller.fill"
        case id.contains("snes") || id.contains("famicom"):
            return "gamecontroller.fill"
        case id.contains("n64") || id.contains("nintendo64"):
            return "gamecontroller.fill"
        case id.contains("gamecube") || id.contains("wii") || id.contains("switch"):
            return "gamecontroller.fill"

        // Home consoles — Sony
        case id.contains("playstation") || id.contains(".psx") || id.contains(".ps1")
             || id.contains(".ps2") || id.contains(".ps3"):
            return "gamecontroller.fill"

        // Home consoles — Sega
        case id.contains("genesis") || id.contains("megadrive") || id.contains("saturn")
             || id.contains("dreamcast") || id.contains("mastersystem") || id.contains("32x"):
            return "gamecontroller.fill"

        // Home consoles — Other
        case id.contains("coleco") || id.contains("colecovision"):
            return "gamecontroller.fill"

        // Computers / DOS
        case id.contains("dos") || id.contains("doom") || id.contains("amiga")
             || id.contains("atarist") || id.contains("msx") || id.contains("spectrum")
             || id.contains("c64") || id.contains("appleii")
             || id.contains("apple2") || id.contains("macintosh") || id.contains("pc98"):
            return "desktopcomputer"

        // Arcade
        case id.contains("arcade") || id.contains("mame") || id.contains("neogeo")
             || id.contains("cps"):
            return "arcade.stick.console.fill"

        default:
            return Defaults.generic
        }
    }

    // MARK: - Private

    private enum Defaults {
        static let generic = "gamecontroller.fill"
    }
}

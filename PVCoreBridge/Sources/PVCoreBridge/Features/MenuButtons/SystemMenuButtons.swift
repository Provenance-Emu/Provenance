//
//  SystemMenuButtons.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/27/26.
//
//  Descriptors for system-specific buttons (Start, Select, Coin, etc.) that
//  some controllers (Siri Remote, older BT pads) lack natively. The pause
//  menu surfaces these as tiles via `SystemButtonTileProvider` so the user
//  can fire them from the on-screen menu.
//

import Foundation
import PVSystems

/// A system-specific button that the pause-menu tile UI can surface when the
/// active controller doesn't have a hardware mapping for it.
///
/// `id` is a stable lowercase string (e.g. `"start"`, `"select"`, `"coin"`)
/// used both as the tile suffix and as the dispatch key in `PauseTileMenuView`.
public struct SystemMenuButton: Sendable, Hashable {
    /// Stable identifier used by the dispatch switch.
    public let id: String
    /// Localized label shown under the tile icon.
    public let label: String
    /// SF Symbol name for the tile icon.
    public let icon: String
    /// True when the tile should appear regardless of controller capability
    /// or `missingButtonsAlwaysOn` (e.g. arcade Coin — no MFi pad maps it).
    public let alwaysShow: Bool

    public init(id: String, label: String, icon: String, alwaysShow: Bool) {
        self.id = id
        self.label = label
        self.icon = icon
        self.alwaysShow = alwaysShow
    }
}

// MARK: - Built-in descriptors per SystemIdentifier

/// Returns the system-specific menu buttons (Start/Select/Coin/etc.) that
/// should be surfaced as pause-menu tiles for the given system.
///
/// Returns an empty array for systems that already cover their hardware
/// buttons via `hardwareMomentaryButtons` (e.g. SMS Pause), are
/// keypad-driven (ColecoVision/Intellivision/Odyssey2), or analog-only
/// (Vectrex).
public func systemMenuButtons(for system: SystemIdentifier) -> [SystemMenuButton] {
    let start = SystemMenuButton(id: "start", label: String(localized: "Start"), icon: "playpause", alwaysShow: false)
    let select = SystemMenuButton(id: "select", label: String(localized: "Select"), icon: "ellipsis.circle", alwaysShow: false)
    let mode = SystemMenuButton(id: "mode", label: String(localized: "Mode"), icon: "gearshape", alwaysShow: false)
    let run = SystemMenuButton(id: "run", label: String(localized: "Run"), icon: "playpause", alwaysShow: false)
    let pause = SystemMenuButton(id: "pause", label: String(localized: "Pause"), icon: "pause.circle", alwaysShow: false)
    let option = SystemMenuButton(id: "option", label: String(localized: "Option"), icon: "ellipsis.circle", alwaysShow: false)
    let option1 = SystemMenuButton(id: "option1", label: String(localized: "Option 1"), icon: "1.circle", alwaysShow: false)
    let option2 = SystemMenuButton(id: "option2", label: String(localized: "Option 2"), icon: "2.circle", alwaysShow: false)
    let coin = SystemMenuButton(id: "coin", label: String(localized: "Insert Coin"), icon: "centsign.circle", alwaysShow: true)
    let sound = SystemMenuButton(id: "sound", label: String(localized: "Sound"), icon: "speaker.wave.2", alwaysShow: false)
    let power = SystemMenuButton(id: "power", label: String(localized: "Power"), icon: "power", alwaysShow: false)
    let shake = SystemMenuButton(id: "shake", label: String(localized: "Shake"), icon: "waveform.path", alwaysShow: false)
    let stop = SystemMenuButton(id: "stop", label: String(localized: "Stop"), icon: "stop.circle", alwaysShow: false)
    let p3do = SystemMenuButton(id: "p", label: String(localized: "P"), icon: "p.circle", alwaysShow: false)

    switch system {
    // Standard Start + Select pads
    case .NES, .FDS, .SNES, .GB, .GBC, .GBA, .DS,
         .PSX, .PS2, .PS3, .PSP,
         .VirtualBoy, .MegaDuck:
        return [start, select]

    // WonderSwan: Start + Sound (no Select on hardware)
    case .WonderSwan, .WonderSwanColor:
        return [start, sound]

    // Start-only consoles (analog/digital but only one menu button)
    case .N64, .Saturn, .Dreamcast, .GameCube:
        return [start]

    // Sega arcade boards (flycast). They share Dreamcast's button set, but are
    // coin-op hardware, so they default to an arcade menu set including Coin.
    // `PVDreamcastButton` gained a `.coin` case for exactly this (the wrapper
    // maps it to SELECT, which the Dreamcast pad never uses).
    case .NAOMI, .NAOMI2, .Atomiswave:
        return [start, coin]

    // Genesis family — Start + Mode
    case .Genesis, .SegaCD, .GameGear, .Sega32X:
        return [start, mode]

    // SMS / SG-1000: SMS Pause is already covered by hardwareMomentaryButtons
    // on PVMasterSystemButton; SG1000 only has Start.
    case .MasterSystem:
        return []
    case .SG1000:
        return [start]

    // PC Engine family — Run + Select
    case .PCE, .PCECD, .SGFX, .PCFX:
        return [run, select]

    // Neo Geo Pocket — Option only
    case .NGP, .NGPC:
        return [option]

    // Arcade (MAME / CPS) — Start + Select + Coin (always-on)
    case .MAME, .CPS1, .CPS2, .CPS3:
        return [start, select, coin]

    // NeoGeo / NeoGeoCD — PVNeoGeoButton has no `coin` case, so we cannot
    // emit a Coin tile here. Surface Start + Select only.
    case .NeoGeo, .NeoGeoCD:
        return [start, select]

    // Atari Lynx — Pause + Option1/2
    case .Lynx:
        return [pause, option1, option2]

    // Atari Jaguar — Pause + Option (PVJaguarButton has both)
    case .AtariJaguar, .AtariJaguarCD:
        return [pause, option]

    // 3DO — Stop + P (start)
    case ._3DO:
        return [stop, p3do]

    // Pokemon Mini — Power + Shake (button is `shake`, not `shock`)
    case .PokemonMini:
        return [power, shake]

    // Supervision — Start (enter) + Select (clear). PVSupervisionButton
    // names them differently on hardware but the init() aliases match.
    case .Supervision:
        return [start, select]

    // Keypad-driven, analog-only, or already covered: skip
    case .ColecoVision, .Intellivision, .Vectrex, .Odyssey2,
         .Atari2600, .Atari5200, .Atari7800, .Atari8bit,
         .EP128, .ZXSpectrum, .C64, .MSX, .MSX2, .AppleII,
         .DOS, .DOOM, .Quake, .Quake2, .Wolf3D,
         .AtariST, .Macintosh, .PC98, .PalmOS,
         .CDi, .Wii, ._3DS,
         .TIC80, .Music, .RetroArch, .Unknown:
        return []
    }
}

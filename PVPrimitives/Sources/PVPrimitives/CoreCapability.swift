//
//  CoreCapability.swift
//  PVPrimitives
//
//  Created by Claude on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// A discrete capability that an emulator core may support.
///
/// Capabilities are used by ``CoreRecommendationEngine`` to rank available cores
/// for a given game and to display rich metadata in the core-selection UI.
public enum CoreCapability: String, Codable, CaseIterable, Sendable, Hashable {

    // MARK: - Input capabilities

    /// Core emulates a mouse/trackball peripheral (e.g. SNES Mouse, PC-88 mouse).
    case mouseSupport = "mouseSupport"

    /// Core emulates a light-gun peripheral (e.g. NES Zapper, Super Scope).
    case lightgunSupport = "lightgunSupport"

    /// Core supports multi-tap / 4+ player adapters.
    case multitapSupport = "multitapSupport"

    /// Core emulates a real microphone (not pseudo white-noise generation).
    case realMicrophone = "realMicrophone"

    /// Core supports the host camera for in-game camera features.
    case cameraSupport = "cameraSupport"

    /// Core supports rumble / force-feedback output.
    case rumble = "rumble"

    // MARK: - Network capabilities

    /// Core supports local wireless (ad-hoc) multiplayer.
    case localWireless = "localWireless"

    /// Core supports online netplay.
    case netplay = "netplay"

    // MARK: - Accuracy & compatibility

    /// Core is considered high-accuracy / cycle-exact.
    case highAccuracy = "highAccuracy"

    /// Core prioritises speed over strict accuracy.
    case highPerformance = "highPerformance"

    /// Core passes most known test-ROMs for the target hardware.
    case testRomAccurate = "testRomAccurate"

    // MARK: - Enhancement features

    /// Core supports widescreen hacks or aspect-ratio overrides.
    case widescreenSupport = "widescreenSupport"

    /// Core can render at resolutions above native (HD / HiRes mode).
    case enhancedResolution = "enhancedResolution"

    /// Core supports run-ahead to reduce perceived input latency.
    case runAhead = "runAhead"

    /// Core supports rewind gameplay.
    case rewind = "rewind"

    // MARK: - Media capabilities

    /// Core supports CD-DA / CD audio playback.
    case cdAudio = "cdAudio"

    /// Core supports playing audio from a real audio CD or CD image with sub-channel data.
    case subChannelAudio = "subChannelAudio"

    // MARK: - Save & peripheral emulation

    /// Core supports in-app cheat codes.
    case cheats = "cheats"

    /// Core emulates the Transfer Pak accessory (N64).
    case transferPak = "transferPak"

    /// Core emulates the GB Player (GameCube attachment for playing GBA games).
    case gbPlayer = "gbPlayer"

    /// Core emulates the e-Reader / Barcode Boy accessory.
    case barcodeReader = "barcodeReader"

    // MARK: - Runtime requirements

    /// Core requires JIT compilation to run at acceptable speed.
    case requiresJIT = "requiresJIT"

    /// Core requires a specific BIOS file to function.
    case requiresBIOS = "requiresBIOS"
}

// MARK: - Display helpers

public extension CoreCapability {

    /// Human-readable name shown in the core-selection UI.
    var displayName: String {
        switch self {
        case .mouseSupport:        return "Mouse Support"
        case .lightgunSupport:     return "Light Gun"
        case .multitapSupport:     return "Multitap / 4+ Players"
        case .realMicrophone:      return "Real Microphone"
        case .cameraSupport:       return "Camera"
        case .rumble:              return "Rumble"
        case .localWireless:       return "Local Wireless"
        case .netplay:             return "Netplay"
        case .highAccuracy:        return "High Accuracy"
        case .highPerformance:     return "High Performance"
        case .testRomAccurate:     return "Test-ROM Accurate"
        case .widescreenSupport:   return "Widescreen"
        case .enhancedResolution:  return "HD / Enhanced Resolution"
        case .runAhead:            return "Run-Ahead (low latency)"
        case .rewind:              return "Rewind"
        case .cdAudio:             return "CD Audio"
        case .subChannelAudio:     return "Sub-Channel Audio"
        case .cheats:              return "Cheat Codes"
        case .transferPak:         return "Transfer Pak"
        case .gbPlayer:            return "GB Player"
        case .barcodeReader:       return "Barcode Reader"
        case .requiresJIT:         return "Requires JIT"
        case .requiresBIOS:        return "Requires BIOS"
        }
    }

    /// SF Symbol name for displaying this capability as an icon.
    var sfSymbol: String {
        switch self {
        case .mouseSupport:        return "cursorarrow"
        case .lightgunSupport:     return "scope"
        case .multitapSupport:     return "person.3.fill"
        case .realMicrophone:      return "mic.fill"
        case .cameraSupport:       return "camera.fill"
        case .rumble:              return "iphone.radiowaves.left.and.right"
        case .localWireless:       return "wifi"
        case .netplay:             return "network"
        case .highAccuracy:        return "checkmark.seal.fill"
        case .highPerformance:     return "bolt.fill"
        case .testRomAccurate:     return "checkmark.circle.fill"
        case .widescreenSupport:   return "rectangle.ratio.16.to.9.fill"
        case .enhancedResolution:  return "sparkles.tv.fill"
        case .runAhead:            return "gauge.with.dots.needle.67percent"
        case .rewind:              return "backward.fill"
        case .cdAudio:             return "opticaldisc"
        case .subChannelAudio:     return "music.note"
        case .cheats:              return "command.square.fill"
        case .transferPak:         return "arrow.triangle.2.circlepath"
        case .gbPlayer:            return "gamecontroller.fill"
        case .barcodeReader:       return "barcode"
        case .requiresJIT:         return "cpu"
        case .requiresBIOS:        return "doc.fill"
        }
    }

    /// Whether this capability is a requirement/limitation (negative context) rather than a feature.
    var isRequirement: Bool {
        switch self {
        case .requiresJIT, .requiresBIOS: return true
        default: return false
        }
    }
}

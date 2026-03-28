//
//  KnownEmulator.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 3/28/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// A known third-party emulator that may be installed on the user's device.
///
/// iOS sandboxing prevents direct file access to other apps' containers, but
/// we can probe for their presence via URL schemes and guide users through
/// manual export/import workflows.
public enum KnownEmulator: String, CaseIterable, Sendable {
    /// Delta — Nintendo multi-system emulator by Riley Testut.
    /// Supports NES, SNES, N64, GBA, GBC, DS.
    case delta

    /// Manic Emu — GBA, NES, SNES, and Sega Genesis emulator.
    case manic

    /// RetroArch — multi-system emulator frontend with a large core library.
    case retroArch

    /// PPSSPP — PSP emulator.
    case ppsspp

    /// Gamma — Game Boy / Game Boy Color emulator.
    case gamma
}

// MARK: - Display properties

public extension KnownEmulator {
    /// Human-readable name of the emulator.
    var displayName: String {
        switch self {
        case .delta:     return "Delta"
        case .manic:     return "Manic Emu"
        case .retroArch: return "RetroArch"
        case .ppsspp:    return "PPSSPP"
        case .gamma:     return "Gamma"
        }
    }

    /// Bundle identifier of the emulator app.
    var bundleIdentifier: String {
        switch self {
        case .delta:     return "com.rileytestut.Delta"
        case .manic:     return "com.manticstudios.ManticEmu"
        case .retroArch: return "com.libretro.RetroArch"
        case .ppsspp:    return "org.ppsspp.ppsspp"
        case .gamma:     return "com.littleredgames.GambatteGB"
        }
    }

    /// URL scheme used to probe whether the app is installed.
    /// `nil` if the emulator has no registered URL scheme.
    var urlScheme: String? {
        switch self {
        case .delta:     return "delta"
        case .manic:     return nil
        case .retroArch: return "retroarch"
        case .ppsspp:    return "ppsspp"
        case .gamma:     return nil
        }
    }

    /// SF Symbol name that best represents this emulator's primary platform(s).
    var symbolName: String {
        switch self {
        case .delta:     return "gamecontroller.fill"
        case .manic:     return "bolt.fill"
        case .retroArch: return "cpu.fill"
        case .ppsspp:    return "memorychip"
        case .gamma:     return "squareshape.dotted.squareshape"
        }
    }

    /// Short description of which systems/games this emulator handles.
    var systemSummary: String {
        switch self {
        case .delta:     return "NES, SNES, N64, GBA, GBC, DS"
        case .manic:     return "GBA, NES, SNES, Genesis"
        case .retroArch: return "60+ systems"
        case .ppsspp:    return "PlayStation Portable (PSP)"
        case .gamma:     return "Game Boy, Game Boy Color"
        }
    }

    /// The save-file extension(s) this emulator primarily uses.
    var saveExtensions: [String] {
        switch self {
        case .delta:     return ["sav", "ssv"]
        case .manic:     return ["sav", "srm"]
        case .retroArch: return ["sav", "srm", "state"]
        case .ppsspp:    return ["ppst"]
        case .gamma:     return ["sav"]
        }
    }
}

// MARK: - Detection

public extension KnownEmulator {
    /// Returns `true` when the emulator appears to be installed.
    ///
    /// Detection is performed via `UIApplication.canOpenURL(_:)`, which requires
    /// the scheme to be listed in `LSApplicationQueriesSchemes` inside Info.plist.
    /// On tvOS and simulator builds this always returns `false`.
    @MainActor
    var isInstalled: Bool {
        #if os(iOS) && !targetEnvironment(simulator)
        guard let scheme = urlScheme,
              let url = URL(string: "\(scheme)://") else {
            return false
        }
        // UIApplication is only available when imported via UIKit
        // We use dynamic lookup to avoid a hard UIKit import in PVPrimitives.
        guard let application = NSClassFromString("UIApplication"),
              let shared = application.value(forKeyPath: "sharedApplication") as? NSObject else {
            return false
        }
        return (shared.perform(NSSelectorFromString("canOpenURL:"), with: url)?.takeUnretainedValue() as? Bool) ?? false
        #else
        return false
        #endif
    }

    /// Returns all emulators that are detected as installed on the current device.
    @MainActor
    static var installedEmulators: [KnownEmulator] {
        KnownEmulator.allCases.filter { $0.isInstalled }
    }
}

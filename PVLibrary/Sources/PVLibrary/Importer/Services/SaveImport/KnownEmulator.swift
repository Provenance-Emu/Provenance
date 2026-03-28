//
//  KnownEmulator.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-27.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Registry of known third-party emulators for migration detection.
//  Part of issue #3552 (save import/export protocols foundation).
//

import Foundation
#if canImport(UIKit) && !os(tvOS)
import UIKit
#endif

// MARK: - KnownEmulator

/// Known third-party emulator apps that Provenance can guide users to migrate saves from.
///
/// Install detection uses URL-scheme probing — only works for schemes listed in
/// `LSApplicationQueriesSchemes` in the app's `Info.plist`.
public enum KnownEmulator: String, CaseIterable, Codable, Sendable {

    // Nintendo / multi-system
    case delta      = "com.rileytestut.Delta"
    case deltaLite  = "com.rileytestut.Delta-Lite"
    // TODO: Verify Gamma's bundle ID before the save-migration feature ships.
    // "com.littleredgames.GambatteGB" is unconfirmed; Gamma (by Riley Testut) may use
    // a different bundle ID. isInstalled / exportDeepLinkURL will silently no-op until
    // the URL scheme is also added to LSApplicationQueriesSchemes in Info.plist.
    case gamma      = "com.littleredgames.GambatteGB"

    // Multi-system / libretro
    case retroArch  = "com.libretro.RetroArch"

    // Manic EMU (by aoshuang) — GBA, NES, SNES, Genesis, N64, and more.
    // URL scheme: manicemu   App Group: group.aoshuang.manicemu
    case manicEmu   = "com.aoshuang.manicemu"

    // Consoles — iOS/tvOS multi-system emulator.
    // TODO: Verify bundle ID and URL scheme once publicly available.
    case consoles   = "com.consoles.emulator"

    // PSP
    case ppsspp     = "org.ppsspp.ppsspp"

    // MARK: - Display

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .delta, .deltaLite: return "Delta"
        case .gamma:             return "Gamma"
        case .retroArch:         return "RetroArch"
        case .manicEmu:          return "Manic EMU"
        case .consoles:          return "Consoles"
        case .ppsspp:            return "PPSSPP"
        }
    }

    /// The app's bundle identifier.
    public var bundleID: String { rawValue }

    // MARK: - Supported File Extensions

    /// Battery/SRAM save file extensions produced by this emulator.
    public var saveFileExtensions: [String] {
        switch self {
        case .delta, .deltaLite: return ["dsv", "sav", "srm"]
        case .gamma:             return ["sav", "srm"]
        case .retroArch:         return ["srm", "rtc"]
        case .manicEmu:          return ["sav", "srm"]
        case .consoles:          return ["sav", "srm"]
        case .ppsspp:            return ["sav"]
        }
    }

    /// Save-state file extensions produced by this emulator.
    public var stateFileExtensions: [String] {
        switch self {
        case .delta, .deltaLite: return ["dvsave"]
        case .retroArch:         return ["state", "auto",
                                         "state0", "state1", "state2",
                                         "state3", "state4", "state5", "state6",
                                         "state7", "state8", "state9"]
        case .ppsspp:            return ["ppst"]
        case .gamma, .manicEmu, .consoles: return []
        }
    }

    // MARK: - App Group

    /// Shared app group container identifier, if any.
    ///
    /// When non-nil, Provenance can use `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`
    /// to access shared storage — enabling future direct save-file import without the export flow.
    public var appGroupIdentifier: String? {
        switch self {
        case .manicEmu:  return "group.aoshuang.manicemu"
        default:         return nil
        }
    }

    // MARK: - Install Detection

    /// URL scheme used to probe whether this emulator is installed.
    public var urlScheme: String? {
        switch self {
        case .delta, .deltaLite: return "delta"
        case .retroArch:         return "retroarch"
        case .ppsspp:            return "ppsspp"
        case .manicEmu:          return "manicemu"
        case .consoles:          return "consolesapp" // TODO: confirm scheme
        case .gamma:             return nil
        }
    }

    /// Returns `true` if this emulator appears to be installed on the device.
    ///
    /// Uses `UIApplication.canOpenURL` internally.  Requires that the relevant
    /// URL schemes are declared in `LSApplicationQueriesSchemes` in `Info.plist`.
    /// Always returns `false` on tvOS, macOS, and Linux.
    @MainActor
    public var isInstalled: Bool {
        guard let scheme = urlScheme, let url = URL(string: "\(scheme)://") else {
            return false
        }
#if canImport(UIKit) && !os(tvOS)
        return UIApplication.shared.canOpenURL(url)
#else
        return false
#endif
    }

    // MARK: - Deep-Link Export

    /// A deep-link URL that opens the emulator to its export or share UI, if available.
    /// Returns `nil` if the emulator has no known export deep link.
    public var exportDeepLinkURL: URL? {
        switch self {
        case .delta, .deltaLite: return URL(string: "delta://")
        case .retroArch:         return URL(string: "retroarch://")
        case .manicEmu:          return URL(string: "manicemu://")
        case .gamma, .consoles, .ppsspp: return nil
        }
    }

    // MARK: - App Group Shared Container

    /// Returns the shared container URL for this emulator's app group, if available and accessible.
    ///
    /// Returns `nil` on tvOS, macOS, and simulator builds — and when the group identifier is
    /// not configured in the host app's entitlements.
    public var sharedContainerURL: URL? {
        guard let groupID = appGroupIdentifier else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }
}

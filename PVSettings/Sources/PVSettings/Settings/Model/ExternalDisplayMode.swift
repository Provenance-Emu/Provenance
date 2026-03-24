//
//  ExternalDisplayMode.swift
//  PVSettings
//
//  Created by Provenance Emu on 2026-03-24.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults

/// Controls how game content is presented when an external display is connected.
///
/// - `systemMirror`: The OS mirrors the entire device screen (no special handling). Works with every core.
/// - `dedicated`: The game-only GPU view is moved to the external display; the device shows the controller skin only.
///   Requires the active core to have `supportsExternalDisplay == true`; otherwise falls back to `.systemMirror`.
public enum ExternalDisplayMode: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    /// Use the system's built-in screen mirroring / AirPlay mirror.
    /// Compatible with every core and renderer.
    case systemMirror = "systemMirror"

    /// Move the game view to the external display and keep the controller skin
    /// on the device screen.  Only available for Metal-based standard cores;
    /// unsupported cores fall back to `.systemMirror` at runtime.
    case dedicated = "dedicated"

    // MARK: Display

    public var displayName: String {
        switch self {
        case .systemMirror: return "System Mirror"
        case .dedicated:    return "Dedicated (Game on TV)"
        }
    }

    public var subtitle: String {
        switch self {
        case .systemMirror:
            return "Mirror the entire device screen via AirPlay or cable"
        case .dedicated:
            return "Show game-only view on external display; controller on device (requires compatible core)"
        }
    }

    public var symbolName: String {
        switch self {
        case .systemMirror: return "rectangle.on.rectangle"
        case .dedicated:    return "tv.and.hifispeaker.fill"
        }
    }
}

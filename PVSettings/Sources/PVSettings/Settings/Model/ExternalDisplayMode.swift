//
//  ExternalDisplayMode.swift
//  PVSettings
//
//  Created by Provenance Emu on 2026-03-24.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults

/// Controls how game content is presented when an external display is connected
/// (a cabled display, or an AirPlay screen: both arrive as the same kind of screen).
///
/// - `dedicated`: the external display shows the game picture on its own, with no touch controls.
///   Cores that draw into a view of their own cannot do this and are mirrored instead.
/// - `systemMirror`: the OS mirrors the entire device screen (no special handling). Works with every core.
public enum ExternalDisplayMode: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    /// Use the system's built-in screen mirroring.
    case systemMirror = "systemMirror"

    /// Show the game picture alone on the external display.
    case dedicated = "dedicated"

    // MARK: Display

    public var displayName: String {
        switch self {
        case .systemMirror: return "Mirror Device"
        case .dedicated:    return "Game on External Display"
        }
    }

    public var subtitle: String {
        switch self {
        case .systemMirror:
            return "Copy the whole device screen, touch controls included"
        case .dedicated:
            return "Show only the game picture on the display; controls stay on the device"
        }
    }

    public var symbolName: String {
        switch self {
        case .systemMirror: return "rectangle.on.rectangle"
        case .dedicated:    return "tv"
        }
    }
}

/// Whether the device keeps showing the game picture while an external display shows it.
public enum ExternalDisplayDevicePicture: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    /// Decide from how the game is being played (see `ExternalDisplayPlan`).
    case auto
    /// The picture is on both screens.
    case on
    /// Only the external display shows the picture.
    case off

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .on:   return "On"
        case .off:  return "Off"
        }
    }
}

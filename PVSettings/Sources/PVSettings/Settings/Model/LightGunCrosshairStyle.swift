//
//  LightGunCrosshairStyle.swift
//  PVSettings
//
//  Created by Provenance Emu on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults

/// Visual style for the light gun crosshair overlay rendered over the game screen.
///
/// The overlay is only shown when the active core reports `gameSupportsLightGun == true`.
public enum LightGunCrosshairStyle: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    /// No crosshair overlay is drawn.
    case off = "off"

    /// A single filled circle at the cursor position.
    case dot = "dot"

    /// Classic + crosshair lines with a gap at the centre.
    case crosshair = "crosshair"

    /// Circle with crosshair lines (scope-style reticle).
    case reticle = "reticle"

    // MARK: Display

    public var displayName: String {
        switch self {
        case .off:       return "Off"
        case .dot:       return "Dot"
        case .crosshair: return "Crosshair"
        case .reticle:   return "Reticle"
        }
    }

    public var subtitle: String {
        switch self {
        case .off:       return "No crosshair shown"
        case .dot:       return "Small dot at aim position"
        case .crosshair: return "Classic + crosshair lines"
        case .reticle:   return "Circle with crosshair"
        }
    }

    public var symbolName: String {
        switch self {
        case .off:       return "eye.slash"
        case .dot:       return "circle.fill"
        case .crosshair: return "plus"
        case .reticle:   return "scope"
        }
    }
}

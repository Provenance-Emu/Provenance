//
//  LightGunCrosshairStyle.swift
//  PVSettings
//
//  Style of the on-screen crosshair overlay rendered during light gun gameplay.
//

import Foundation
@_exported import Defaults

/// Controls what visual indicator, if any, is drawn over the game image to show
/// where the light gun is currently aimed.
public enum LightGunCrosshairStyle: String, Codable, Equatable, Defaults.Serializable,
    CaseIterable, Sendable {

    /// No crosshair overlay — the core's own sprite (if any) is used.
    case off

    /// A small filled dot at the aim point.
    case dot

    /// A traditional crosshair (plus-sign reticle) at the aim point.
    case crosshair

    /// Circle with crosshair lines (scope-style reticle) at the aim point.
    case reticle

    // MARK: Display

    public var displayTitle: String {
        switch self {
        case .off:       return "Off"
        case .dot:       return "Dot"
        case .crosshair: return "Crosshair"
        case .reticle:   return "Reticle"
        }
    }

    public var displayDescription: String {
        switch self {
        case .off:
            return "No crosshair overlay (use core's own sprite)"
        case .dot:
            return "Show a small dot at the aim point"
        case .crosshair:
            return "Show a crosshair reticle at the aim point"
        case .reticle:
            return "Show a circle with crosshair lines at the aim point"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .off:       return "eye.slash"
        case .dot:       return "circle.fill"
        case .crosshair: return "plus"
        case .reticle:   return "scope"
        }
    }

    /// Compatibility alias for legacy callers expecting `displayName`.
    public var displayName: String { displayTitle }

    /// Compatibility alias for legacy callers expecting `subtitle`.
    public var subtitle: String { displayDescription }

    /// Compatibility alias for legacy callers expecting `symbolName`.
    public var symbolName: String { sfSymbolName }
}

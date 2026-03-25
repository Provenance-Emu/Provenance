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

    /// A small filled dot at the aim point.
    case dot

    /// A traditional crosshair (plus-sign reticle) at the aim point.
    case crosshair

    /// No crosshair overlay — the core's own sprite (if any) is used.
    case off

    // MARK: Display

    public var displayTitle: String {
        switch self {
        case .dot:       return "Dot"
        case .crosshair: return "Crosshair"
        case .off:       return "Off"
        }
    }

    public var displayDescription: String {
        switch self {
        case .dot:
            return "Show a small dot at the aim point"
        case .crosshair:
            return "Show a crosshair reticle at the aim point"
        case .off:
            return "No crosshair overlay (use core's own sprite)"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .dot:       return "circle.fill"
        case .crosshair: return "plus.viewfinder"
        case .off:       return "eye.slash"
        }
    }
}

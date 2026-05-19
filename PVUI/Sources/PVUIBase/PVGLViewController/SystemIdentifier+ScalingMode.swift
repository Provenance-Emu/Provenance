//
//  SystemIdentifier+ScalingMode.swift
//  PVUIBase
//
//  Per-system default ScalingMode mapping for the renderer. Lives in PVUI
//  (not PVSystems/PVPrimitives) because the `ScalingMode` enum is defined
//  in PVSettings, and PVPrimitives deliberately does not depend on
//  PVSettings. See `Defaults[.userExplicitlySetScalingMode]` for the gate
//  that decides whether this default or the user-picked value wins.
//

import Foundation
import PVSettings
import PVSystems

public extension SystemIdentifier {

    /// The scaling mode that best matches the system's native presentation
    /// when the user hasn't explicitly chosen one. Returned only as a
    /// fallback by the renderer — once the user picks any value in
    /// settings (`Defaults[.userExplicitlySetScalingMode] == true`), the
    /// user's choice always wins.
    ///
    /// Currently overrides the global `.aspectFit` default for
    /// dual-screen handhelds (Nintendo DS) where the upstream libretro
    /// framebuffer is laid out portrait by default (256×384 stacked) —
    /// aspect-fitting that on a 16:9 TV produces tiny slivers in the
    /// middle of the screen. `.stretch` paired with the per-core
    /// `*_screen_layout = "Left/Right"` override applied by
    /// `PVThinLibretroCore.applyPlatformDefaults()` produces a
    /// landscape-friendly fill that uses the whole screen.
    var defaultScalingMode: ScalingMode {
        switch self {
        case .DS:
            return .stretch
        default:
            return .aspectFit
        }
    }
}

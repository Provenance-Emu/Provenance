//
//  ScalingMode.swift
//  PVSettings
//
//  Created by Provenance Emu on 2026-04-01.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults

/// Controls how game video output is scaled to fit the display.
///
/// This replaces the legacy `nativeScaleEnabled` + `integerScaleEnabled` boolean pair
/// with a single composable enum that covers all supported rendering modes.
///
/// ## Mode Summary
/// | Mode | AR Preserved | Fills Screen | Notes |
/// |---|---|---|---|
/// | `.aspectFit` | ✅ | ❌ (pillarbox/letterbox) | Default |
/// | `.aspectFill` | ✅ | ✅ (may crop edges) | |
/// | `.stretch` | ❌ | ✅ | |
/// | `.integerScale` | ✅ | ❌ | Pixel-perfect |
/// | `.nativeResolution` | ✅ | ❌ | 1:1 pixels |
///
/// ## RetroArch / libretro Notes
/// libretro cores report geometry via `retro_game_geometry.aspect_ratio` (float ≤ 0 means
/// use `base_width/base_height`). The renderer updates on `RETRO_ENVIRONMENT_SET_GEOMETRY (37)`
/// or `RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO (33)`. For per-core aspect ratio overrides
/// the relevant core options keys are (verified against upstream sources):
/// - **Mupen64Plus**: `mupen64plus-aspect` → `4:3`, `16:9`, `16:9 adjusted`
/// - **Dolphin**: `dolphin_aspect_ratio` → `"0"` Auto, `"1"` Force Wide, `"2"` Force Standard,
///   `"3"` Stretch, `"4"` Custom, `"5"` Custom Stretch, `"6"` Raw;
///   `dolphin_widescreen_hack` → `disabled/enabled`
/// - **PPSSPP**: has no widescreen option (PSP is natively 480×272 ~16:9)
/// - **Flycast**: `reicast_widescreen_hack` → `disabled/enabled` (NB: prefix is `reicast_`, not `flycast_`)
/// - **DuckStation/Swanstation**: `swanstation_GPU_WidescreenHack` → `true/false`; `swanstation_Display_AspectRatio` → `4:3`, `16:9`, `19:9`, `20:9`, `Custom`, `Auto`, `Native`
/// - **Gearcoleco**: `gearcoleco_aspect_ratio` → `1:1 PAR`, `4:3 DAR`, `16:9 DAR`, `16:10 DAR`
/// - **Genesis Plus GX**: `genesis_plus_gx_aspect_ratio` → `auto`, `NTSC PAR`, `PAL PAR` (no widescreen)
/// - **Beetle PSX HW**: `beetle_psx_hw_widescreen_hack` → `disabled/enabled` (software variant: `beetle_psx_widescreen_hack`)
/// These are passed as `RETRO_ENVIRONMENT_GET_VARIABLE` options and can be set via
/// `RETRO_ENVIRONMENT_SET_VARIABLES` callbacks before `retro_load_game`.
public enum ScalingMode: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable,
    CustomStringConvertible {

    /// Scale to fit within the display bounds while preserving the core's reported aspect ratio.
    /// Unused screen area shows the background (pillarboxed or letterboxed).
    /// This is the historical default behavior.
    case aspectFit = "aspectFit"

    /// Scale to fill the entire display while preserving the core's reported aspect ratio.
    /// Content that falls outside the display bounds is cropped.
    case aspectFill = "aspectFill"

    /// Scale to fill the entire display, ignoring the core's reported aspect ratio.
    /// Distortion may be visible, especially on square-pixel systems.
    case stretch = "stretch"

    /// Scale to the nearest integer multiple of the core's native output resolution.
    /// Preserves pixel sharpness at the cost of unused screen border.
    /// Equivalent to the legacy `integerScaleEnabled` setting.
    case integerScale = "integerScale"

    /// Render at the core's exact native pixel resolution (1:1 pixel mapping).
    /// Content will be small on high-DPI screens but pixel-perfect.
    /// Equivalent to the legacy `nativeScaleEnabled` setting.
    case nativeResolution = "nativeResolution"

    // MARK: - Display Metadata

    public var displayName: String {
        switch self {
        case .aspectFit:       return "Aspect Fit"
        case .aspectFill:      return "Aspect Fill"
        case .stretch:         return "Stretch"
        case .integerScale:    return "Integer Scale"
        case .nativeResolution: return "Native Resolution"
        }
    }

    public var subtitle: String {
        switch self {
        case .aspectFit:
            return "Letterbox / pillarbox — preserves aspect ratio"
        case .aspectFill:
            return "Fill screen — preserves aspect ratio, may crop edges"
        case .stretch:
            return "Fill screen completely — ignores aspect ratio"
        case .integerScale:
            return "Pixel-perfect integer multiple of native resolution"
        case .nativeResolution:
            return "1:1 pixel mapping — sharpest but may appear small"
        }
    }

    public var symbolName: String {
        switch self {
        case .aspectFit:       return "aspectratio"
        case .aspectFill:      return "arrow.up.left.and.arrow.down.right"
        case .stretch:         return "arrow.left.and.right.righttriangle.left.righttriangle.right"
        case .integerScale:    return "square.grid.2x2"
        case .nativeResolution: return "1.circle"
        }
    }

    // MARK: - Legacy Compatibility

    /// Derive a `ScalingMode` from the legacy pair of boolean settings.
    /// - Parameters:
    ///   - nativeScale: Legacy `nativeScaleEnabled` value.
    ///   - integerScale: Legacy `integerScaleEnabled` value.
    /// - Returns: The equivalent `ScalingMode`. `integerScale` takes precedence over `nativeScale`.
    public static func fromLegacy(nativeScale: Bool, integerScale: Bool) -> ScalingMode {
        if integerScale { return .integerScale }
        if nativeScale  { return .nativeResolution }
        return .aspectFit
    }

    /// Whether this mode requires the renderer to apply native DPI scaling to the Metal / GL view.
    public var requiresNativeScaleFactor: Bool {
        self == .nativeResolution
    }

    /// Whether this mode snaps dimensions to integer multiples of the core's native resolution.
    public var usesIntegerSnapping: Bool {
        self == .integerScale
    }

    public var description: String { displayName }
}

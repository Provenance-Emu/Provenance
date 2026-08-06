//
//  AspectRatioOverride.swift
//  PVPrimitives
//
//  Created by Provenance Emu on 2026-04-03.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// A per-core aspect ratio override that can be applied on top of the global `ScalingMode`.
///
/// Each emulator core may support a subset of these overrides depending on the capabilities
/// of the underlying emulator. Cores declare which overrides they support via the
/// `CoreOptional.supportedAspectRatioOverrides` property.
///
/// When a core returns a non-`.auto` value from `CoreOptional.preferredAspectRatioOverride`,
/// the renderer applies that override instead of (or in combination with) the global
/// `ScalingMode` setting.
///
/// ## Override vs ScalingMode
/// | `ScalingMode` | `AspectRatioOverride` | Result |
/// |---|---|---|
/// | `.aspectFit` | `.ratio_16_9` | Widescreen content letterboxed to fit |
/// | `.aspectFill` | `.ratio_4_3` | 4:3 content zoomed to fill screen |
/// | `.stretch` | `.auto` | Core's native ratio stretched to fill |
/// | Any | `.ratio_1_1` | Square-pixel / pixel-perfect mapping |
public enum AspectRatioOverride: String, Codable, Equatable, Hashable,
    CaseIterable, Sendable, CustomStringConvertible {

    /// Let the core report its natural aspect ratio — no override applied.
    /// This is the default for all cores.
    case auto = "auto"

    /// Force a 4:3 display ratio (classic TV / arcade).
    case ratio_4_3 = "4:3"

    /// Force a 16:9 widescreen display ratio.
    case ratio_16_9 = "16:9"

    /// Force a 1:1 square-pixel ratio (equal horizontal and vertical scaling).
    case ratio_1_1 = "1:1"

    /// Force a 8:7 ratio used by the SNES / Super Famicom (non-square pixels).
    case ratio_8_7 = "8:7"

    /// Stretch to fill the display, ignoring all aspect ratio constraints.
    /// Equivalent to `ScalingMode.stretch` but applied at the per-core level.
    case stretch = "stretch"

    // MARK: - Display Metadata

    public var displayName: String {
        switch self {
        case .auto:       return "Auto"
        case .ratio_4_3:  return "4:3"
        case .ratio_16_9: return "16:9"
        case .ratio_1_1:  return "1:1"
        case .ratio_8_7:  return "8:7"
        case .stretch:    return "Stretch"
        }
    }

    public var subtitle: String {
        switch self {
        case .auto:
            return "Use the aspect ratio reported by the core"
        case .ratio_4_3:
            return "Classic TV / arcade (4 wide, 3 tall)"
        case .ratio_16_9:
            return "Widescreen — enables widescreen hack if supported"
        case .ratio_1_1:
            return "Square pixels — 1:1 horizontal/vertical mapping"
        case .ratio_8_7:
            return "SNES native — non-square pixel correction"
        case .stretch:
            return "Stretch to fill — ignores aspect ratio"
        }
    }

    public var symbolName: String {
        switch self {
        case .auto:       return "aspectratio"
        case .ratio_4_3:  return "tv"
        case .ratio_16_9: return "tv.fill"
        case .ratio_1_1:  return "square"
        case .ratio_8_7:  return "rectangle"
        case .stretch:    return "arrow.left.and.right.righttriangle.left.righttriangle.right"
        }
    }

    /// The floating-point aspect ratio value, or `nil` for `.auto` and `.stretch`.
    public var aspectRatioValue: Float? {
        switch self {
        case .auto:       return nil
        case .ratio_4_3:  return 4.0 / 3.0
        case .ratio_16_9: return 16.0 / 9.0
        case .ratio_1_1:  return 1.0
        case .ratio_8_7:  return 8.0 / 7.0
        case .stretch:    return nil
        }
    }

    /// Whether this override requests widescreen rendering (16:9 or wider).
    public var isWidescreen: Bool {
        switch self {
        case .ratio_16_9: return true
        default: return false
        }
    }

    public var description: String { displayName }
}

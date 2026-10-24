//
//  ImageSmoothingMode.swift
//  PVSettings
//
//  Created by Provenance Emu on 2026-10-23.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults

/// How the game picture is sampled when it is scaled to the screen.
///
/// Replaces the legacy `imageSmoothing` boolean. `sharpBilinear` is drawn by
/// Provenance's own Metal blit only; every other renderer (slang presets, native
/// Metal filters, Dolphin, PPSSPP) treats it as `bilinear`.
public enum ImageSmoothingMode: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    /// Nearest-neighbour: hard pixel edges, uneven pixel widths at non-integer scales.
    case nearest

    /// Bilinear: soft picture with no stair-stepping.
    case bilinear

    /// Integer-prescale then bilinear: pixels stay sharp and only the one-pixel seams
    /// between them are blended, so non-integer scales don't shimmer.
    case sharpBilinear

    /// Whether renderers with only a nearest/linear choice should sample linearly.
    public var usesLinearFiltering: Bool {
        self != .nearest
    }

    public var displayName: String {
        switch self {
        case .nearest:       return "Off (Sharp Pixels)"
        case .bilinear:      return "Bilinear"
        case .sharpBilinear: return "Sharp Bilinear"
        }
    }

    public var subtitle: String {
        switch self {
        case .nearest:
            return "Hard pixel edges; pixels can vary in width at non-integer scales."
        case .bilinear:
            return "Soft, blended picture."
        case .sharpBilinear:
            return "Crisp pixels with even widths. Bilinear on Dolphin, PPSSPP and display filters; not used by 3DS cores."
        }
    }

    public var symbolName: String {
        switch self {
        case .nearest:       return "square.grid.3x3"
        case .bilinear:      return "paintbrush.pointed"
        case .sharpBilinear: return "square.grid.3x3.middle.filled"
        }
    }

    /// The mode the legacy `imageSmoothing` boolean meant.
    public static func fromLegacy(imageSmoothing: Bool) -> ImageSmoothingMode {
        imageSmoothing ? .bilinear : .nearest
    }
}

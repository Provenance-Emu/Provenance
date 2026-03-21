//
//  PokeMiniPalette.swift
//  PVPokeMiniOptions
//
//  Part of #2649 — Custom Palette System
//  Sub-task 4: PokeMini PaletteProviding adoption
//

import PVCoreBridge

// MARK: - PokeMiniPalette

/// All 14 built-in display palettes supported by the PokéMini emulator.
///
/// Each palette is a 2-colour (light/dark) scheme. `light` maps to the OFF
/// pixel and `dark` to the ON pixel, matching `p0`/`p1` in `Video.c`.
@objc public enum PokeMiniPalette: Int, CaseIterable {
    case defaultGreen    = 0   // "Default"
    case old             = 1   // "Old PokeMini"
    case monochrome      = 2   // "Black & White"
    case green           = 3   // "Green Palette"
    case greenVector     = 4   // "Green Vector"
    case red             = 5   // "Red Palette"
    case redVector       = 6   // "Red Vector"
    case blueLCD         = 7   // "Blue LCD"
    case ledBacklight    = 8   // "LED Backlight"
    case girlPower       = 9   // "Girlish"
    case blue            = 10  // "Blue Palette"
    case blueVector      = 11  // "Blue Vector"
    case sepia           = 12  // "Sepia"
    case monochromeVector = 13 // "Inv. B&W"

    public static var `default`: PokeMiniPalette { .defaultGreen }
}

// MARK: - Stable IDs

extension PokeMiniPalette {
    /// Stable string identifier used by `PaletteProviding`.
    /// Based on case name so reordering cannot break saved preferences.
    public var paletteID: String {
        switch self {
        case .defaultGreen:    return "defaultGreen"
        case .old:             return "old"
        case .monochrome:      return "monochrome"
        case .green:           return "green"
        case .greenVector:     return "greenVector"
        case .red:             return "red"
        case .redVector:       return "redVector"
        case .blueLCD:         return "blueLCD"
        case .ledBacklight:    return "ledBacklight"
        case .girlPower:       return "girlPower"
        case .blue:            return "blue"
        case .blueVector:      return "blueVector"
        case .sepia:           return "sepia"
        case .monochromeVector: return "monochromeVector"
        }
    }

    /// Human-readable name shown in the palette picker UI.
    public var displayName: String {
        switch self {
        case .defaultGreen:    return "Default"
        case .old:             return "Old PokéMini"
        case .monochrome:      return "Monochrome"
        case .green:           return "Green"
        case .greenVector:     return "Green Vector"
        case .red:             return "Red"
        case .redVector:       return "Red Vector"
        case .blueLCD:         return "Blue LCD"
        case .ledBacklight:    return "LED Backlight"
        case .girlPower:       return "Girl Power"
        case .blue:            return "Blue"
        case .blueVector:      return "Blue Vector"
        case .sepia:           return "Sepia"
        case .monochromeVector: return "Monochrome Vector"
        }
    }

    /// Two preview colours: index 0 = light (OFF pixel), index 1 = dark (ON pixel).
    /// Hex values match `p0`/`p1` in `PokeMini_VideoPalette_Index()` in `Video.c`.
    public var previewColors: [PaletteColor] {
        switch self {
        case .defaultGreen:
            return [.init(hex: 0xB4C8B4), .init(hex: 0x122412)]
        case .old:
            return [.init(hex: 0x8EAD92), .init(hex: 0x4A5542)]
        case .monochrome:
            return [.init(hex: 0xFFFFFF), .init(hex: 0x000000)]
        case .green:
            return [.init(hex: 0x00FF00), .init(hex: 0x000000)]
        case .greenVector:
            return [.init(hex: 0x000000), .init(hex: 0x00FF00)]
        case .red:
            return [.init(hex: 0xFF0000), .init(hex: 0x000000)]
        case .redVector:
            return [.init(hex: 0x000000), .init(hex: 0xFF0000)]
        case .blueLCD:
            return [.init(hex: 0xC0C0FF), .init(hex: 0x4040FF)]
        case .ledBacklight:
            return [.init(hex: 0xD4D4CF), .init(hex: 0x2A2A17)]
        case .girlPower:
            return [.init(hex: 0xFF80E0), .init(hex: 0xA01880)]
        case .blue:
            return [.init(hex: 0x0000FF), .init(hex: 0x000000)]
        case .blueVector:
            return [.init(hex: 0x000000), .init(hex: 0x0000FF)]
        case .sepia:
            return [.init(hex: 0xD4BC8C), .init(hex: 0x704214)]
        case .monochromeVector:
            return [.init(hex: 0x000000), .init(hex: 0xFFFFFF)]
        }
    }

    /// Converts this palette to a ``CorePalette`` for use with ``PaletteProviding``.
    public var asCorePalette: CorePalette {
        CorePalette(id: paletteID, displayName: displayName, colors: previewColors)
    }
}

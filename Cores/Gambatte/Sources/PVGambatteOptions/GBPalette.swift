//
//  GBPalette.swift
//  PVGambatte
//
//  Created by Joseph Mattiello on 10/9/24.
//

import PVCoreBridge

@objc public enum GBPalette: Int {
    case peaSoupGreen
    case pocket
    case blue
    case darkBlue
    case green
    case darkGreen
    case brown
    case darkBrown
    case red
    case yellow
    case orange
    case pastelMix
    case inverted
    case romTitle
    case grayscale

    public static var `default`: GBPalette { .peaSoupGreen }
}

extension GBPalette: CaseIterable { }

// MARK: - CorePalette colour data

extension GBPalette {
    /// Stable string identifier for this palette (used by `PaletteProviding`).
    /// Uses the case name rather than the raw integer value so reordering cases
    /// cannot silently break saved palette preferences or external references.
    public var paletteID: String {
        switch self {
        case .peaSoupGreen: return "peaSoupGreen"
        case .pocket:       return "pocket"
        case .blue:         return "blue"
        case .darkBlue:     return "darkBlue"
        case .green:        return "green"
        case .darkGreen:    return "darkGreen"
        case .brown:        return "brown"
        case .darkBrown:    return "darkBrown"
        case .red:          return "red"
        case .yellow:       return "yellow"
        case .orange:       return "orange"
        case .pastelMix:    return "pastelMix"
        case .inverted:     return "inverted"
        case .romTitle:     return "romTitle"
        case .grayscale:    return "grayscale"
        }
    }

    /// Human-readable name shown in the palette picker UI.
    public var displayName: String {
        switch self {
        case .peaSoupGreen: return "Pea Soup Green"
        case .pocket:       return "GB Pocket"
        case .blue:         return "Blue"
        case .darkBlue:     return "Dark Blue"
        case .green:        return "Green"
        case .darkGreen:    return "Dark Green"
        case .brown:        return "Brown"
        case .darkBrown:    return "Dark Brown"
        case .red:          return "Red"
        case .yellow:       return "Yellow"
        case .orange:       return "Orange"
        case .pastelMix:    return "Pastel Mix"
        case .inverted:     return "Inverted"
        case .romTitle:     return "ROM Title"
        case .grayscale:    return "Grayscale"
        }
    }

    /// Four preview colours, lightest→darkest, used in the `PalettePickerView` swatch.
    public var previewColors: [PaletteColor] {
        switch self {
        case .peaSoupGreen:
            return [.init(hex: 0xE0F0A0), .init(hex: 0x98B048), .init(hex: 0x307030), .init(hex: 0x183800)]
        case .pocket:
            return [.init(hex: 0xC8C0B0), .init(hex: 0x908880), .init(hex: 0x585048), .init(hex: 0x181010)]
        case .blue:
            return [.init(hex: 0xD0E8F8), .init(hex: 0x78A8D8), .init(hex: 0x2858A8), .init(hex: 0x001028)]
        case .darkBlue:
            return [.init(hex: 0xB0C8E8), .init(hex: 0x506898), .init(hex: 0x183868), .init(hex: 0x000818)]
        case .green:
            return [.init(hex: 0xC8F0A0), .init(hex: 0x70C048), .init(hex: 0x188018), .init(hex: 0x003008)]
        case .darkGreen:
            return [.init(hex: 0x90C890), .init(hex: 0x408840), .init(hex: 0x105010), .init(hex: 0x002000)]
        case .brown:
            return [.init(hex: 0xE8C890), .init(hex: 0xB07828), .init(hex: 0x583808), .init(hex: 0x180000)]
        case .darkBrown:
            return [.init(hex: 0xC8A870), .init(hex: 0x886030), .init(hex: 0x402010), .init(hex: 0x100000)]
        case .red:
            return [.init(hex: 0xF0C8C8), .init(hex: 0xD07070), .init(hex: 0x980030), .init(hex: 0x300000)]
        case .yellow:
            return [.init(hex: 0xF8F0A0), .init(hex: 0xD8C030), .init(hex: 0x887800), .init(hex: 0x201800)]
        case .orange:
            return [.init(hex: 0xF8D0A0), .init(hex: 0xE09030), .init(hex: 0x903010), .init(hex: 0x200800)]
        case .pastelMix:
            return [.init(hex: 0xF8E8D0), .init(hex: 0xD0B888), .init(hex: 0x806040), .init(hex: 0x201000)]
        case .inverted:
            return [.init(hex: 0x183800), .init(hex: 0x307030), .init(hex: 0x98B048), .init(hex: 0xE0F0A0)]
        case .romTitle:
            return [.init(hex: 0xC0E8E0), .init(hex: 0x60A8A0), .init(hex: 0x207060), .init(hex: 0x001820)]
        case .grayscale:
            return [.init(hex: 0xE8E8E8), .init(hex: 0xA0A0A0), .init(hex: 0x505050), .init(hex: 0x000000)]
        }
    }

    /// Converts this palette case to a ``CorePalette`` for use with ``PaletteProviding``.
    public var asCorePalette: CorePalette {
        CorePalette(id: paletteID, displayName: displayName, colors: previewColors)
    }
}

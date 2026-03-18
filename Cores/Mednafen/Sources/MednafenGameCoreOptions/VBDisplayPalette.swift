//
//  VBDisplayPalette.swift
//  PVMednafen
//
//  Part of #2649 — Custom Palette System
//  Sub-task: VirtualBoy display-mode palette for PaletteProviding
//
//  Maps Mednafen's 9 VB display modes (anaglyph / 2-D colour presets)
//  to CorePalette swatches shown in the PalettePickerView.
//

import PVCoreBridge

/// Mednafen VirtualBoy display mode.
///
/// The raw value corresponds to the index passed to `selectVBDisplayModeAtIndex:`.
/// The order matches `changeDisplayMode`'s cycling order (0 → 8).
public enum VBDisplayPalette: Int, CaseIterable {
    // 2-D modes (parallax disabled)
    case redBlack       = 0
    case whiteBlack     = 1
    case purpleBlack    = 2
    // 3-D anaglyph modes (parallax enabled)
    case redBlue        = 3
    case redCyan        = 4
    case redElectricCyan = 5
    case redGreen       = 6
    case greenRed       = 7
    case yellowBlue     = 8
}

// MARK: - Identifiers & display

extension VBDisplayPalette {
    /// Stable string identifier (used by `PaletteProviding`).
    public var paletteID: String {
        switch self {
        case .redBlack:        return "vb.redBlack"
        case .whiteBlack:      return "vb.whiteBlack"
        case .purpleBlack:     return "vb.purpleBlack"
        case .redBlue:         return "vb.redBlue"
        case .redCyan:         return "vb.redCyan"
        case .redElectricCyan: return "vb.redElectricCyan"
        case .redGreen:        return "vb.redGreen"
        case .greenRed:        return "vb.greenRed"
        case .yellowBlue:      return "vb.yellowBlue"
        }
    }

    /// Human-readable name shown in the palette picker.
    public var displayName: String {
        switch self {
        case .redBlack:        return "Red / Black (2D)"
        case .whiteBlack:      return "White / Black (2D)"
        case .purpleBlack:     return "Purple / Black (2D)"
        case .redBlue:         return "Red / Blue (3D)"
        case .redCyan:         return "Red / Cyan (3D)"
        case .redElectricCyan: return "Red / Electric Cyan (3D)"
        case .redGreen:        return "Red / Green (3D)"
        case .greenRed:        return "Green / Red (3D)"
        case .yellowBlue:      return "Yellow / Blue (3D)"
        }
    }

    /// Two-colour swatch [left-eye colour, right-eye colour].
    /// A third neutral mid-tone and a black are appended so the swatch always
    /// shows 4 swatches (lightest → darkest convention used by GBPalette).
    public var previewColors: [PaletteColor] {
        switch self {
        case .redBlack:
            return [.init(hex: 0xFF4040), .init(hex: 0xFF0000), .init(hex: 0x800000), .init(hex: 0x000000)]
        case .whiteBlack:
            return [.init(hex: 0xFFFFFF), .init(hex: 0xAAAAAA), .init(hex: 0x555555), .init(hex: 0x000000)]
        case .purpleBlack:
            return [.init(hex: 0xFF80FF), .init(hex: 0xFF00FF), .init(hex: 0x800080), .init(hex: 0x000000)]
        case .redBlue:
            return [.init(hex: 0xFF4040), .init(hex: 0xFF0000), .init(hex: 0x0000FF), .init(hex: 0x000040)]
        case .redCyan:
            return [.init(hex: 0xFF4040), .init(hex: 0xFF0000), .init(hex: 0x00B7EB), .init(hex: 0x005870)]
        case .redElectricCyan:
            return [.init(hex: 0xFF4040), .init(hex: 0xFF0000), .init(hex: 0x00FFFF), .init(hex: 0x007080)]
        case .redGreen:
            return [.init(hex: 0xFF4040), .init(hex: 0xFF0000), .init(hex: 0x00FF00), .init(hex: 0x008000)]
        case .greenRed:
            return [.init(hex: 0x40FF40), .init(hex: 0x00FF00), .init(hex: 0xFF0000), .init(hex: 0x800000)]
        case .yellowBlue:
            return [.init(hex: 0xFFFF40), .init(hex: 0xFFFF00), .init(hex: 0x0000FF), .init(hex: 0x000080)]
        }
    }

    /// Converts this case to a ``CorePalette`` for use with ``PaletteProviding``.
    public var asCorePalette: CorePalette {
        CorePalette(id: paletteID, displayName: displayName, colors: previewColors)
    }
}

// MARK: - Lookup

extension VBDisplayPalette {
    /// Returns the case whose `paletteID` matches, or `nil`.
    public static func from(paletteID id: String) -> VBDisplayPalette? {
        allCases.first { $0.paletteID == id }
    }
}

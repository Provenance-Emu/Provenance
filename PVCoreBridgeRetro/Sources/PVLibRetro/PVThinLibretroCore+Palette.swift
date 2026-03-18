//
//  PVThinLibretroCore+Palette.swift
//  PVCoreBridgeRetro
//
//  Part of #2649 — Custom Palette System
//  Sub-task: PaletteProviding for RetroArch / thin-libretro GB and GBC cores.
//
//  Supported cores (detected by coreIdentifier substring match):
//   • gambatte   — gambatte_gb_colorization + gambatte_gb_internal_palette
//   • mgba       — mgba_gb_colors
//   • sameboy    — (no discrete palette option; excluded)
//   • vbam       — (GBA only; excluded)
//
//  Palette options are applied via the standard libretro core-variable mechanism
//  (RETRO_ENVIRONMENT_GET_VARIABLE / setCoreOption). The core picks up the new
//  value on the next emulation frame when it calls retro_run().
//

import Foundation
import PVCoreBridge
import PVLogging

// MARK: - PaletteProviding

extension PVThinLibretroCore: PaletteProviding {

    // MARK: - availablePalettes

    public var availablePalettes: [CorePalette] {
        let coreID = (coreIdentifier ?? "").lowercased()
        let sysID  = (systemIdentifier ?? "").lowercased()

        // Only expose palettes for DMG Game Boy and Game Boy Color systems.
        // GBA games use full colour; no palette selection makes sense there.
        guard isGBSystem(sysID: sysID) else { return [] }

        if coreID.contains("gambatte") {
            return GambatteLibretroPalette.allCases.map(\.asCorePalette)
        }
        if coreID.contains("mgba") {
            return MGBALibretroPalette.allCases.map(\.asCorePalette)
        }
        return []
    }

    // MARK: - currentPaletteID

    public var currentPaletteID: String {
        let coreID = (coreIdentifier ?? "").lowercased()
        let sysID  = (systemIdentifier ?? "").lowercased()
        guard isGBSystem(sysID: sysID) else { return "" }

        if coreID.contains("gambatte") {
            let option = (_bridge.coreOptions["gambatte_gb_internal_palette"] ?? "GB - DMG")
            return GambatteLibretroPalette.from(optionValue: option)?.paletteID
                ?? GambatteLibretroPalette.dmg.paletteID
        }
        if coreID.contains("mgba") {
            let option = (_bridge.coreOptions["mgba_gb_colors"] ?? "DMG Green")
            return MGBALibretroPalette.from(optionValue: option)?.paletteID
                ?? MGBALibretroPalette.dmgGreen.paletteID
        }
        return ""
    }

    // MARK: - selectPalette

    public func selectPalette(id: String) {
        let coreID = (coreIdentifier ?? "").lowercased()
        let sysID  = (systemIdentifier ?? "").lowercased()
        guard isGBSystem(sysID: sysID) else { return }

        if coreID.contains("gambatte") {
            guard let palette = GambatteLibretroPalette.from(paletteID: id) else { return }
            // Switch colorization to "internal" and set the named palette.
            _bridge.setCoreOption("gambatte_gb_colorization", value: "internal")
            _bridge.setCoreOption("gambatte_gb_internal_palette", value: palette.optionValue)
            ILOG("ThinLibretroCore: gambatte palette → \(palette.optionValue)")
            return
        }
        if coreID.contains("mgba") {
            guard let palette = MGBALibretroPalette.from(paletteID: id) else { return }
            _bridge.setCoreOption("mgba_gb_colors", value: palette.optionValue)
            ILOG("ThinLibretroCore: mGBA GB colors → \(palette.optionValue)")
            return
        }
    }

    // MARK: - Private helpers

    private func isGBSystem(sysID: String) -> Bool {
        // Match GB / GBC but NOT GBA.
        (sysID.contains(".gb") || sysID.contains("gameboy")) && !sysID.contains("gba")
    }
}

// MARK: - Gambatte-libretro palettes

/// Maps to `gambatte_gb_internal_palette` core option values.
enum GambatteLibretroPalette: CaseIterable {
    case dmg
    case pocket
    case light
    case gbcBlue
    case gbcBrown
    case gbcDarkBlue
    case gbcDarkBrown
    case gbcDarkGreen
    case gbcGrayscale
    case gbcGreen
    case gbcInverted
    case gbcOrange
    case gbcPastelMix
    case gbcRed
    case gbcYellow

    var optionValue: String {
        switch self {
        case .dmg:          return "GB - DMG"
        case .pocket:       return "GB - Pocket"
        case .light:        return "GB - Light"
        case .gbcBlue:      return "GBC - Blue"
        case .gbcBrown:     return "GBC - Brown"
        case .gbcDarkBlue:  return "GBC - Dark Blue"
        case .gbcDarkBrown: return "GBC - Dark Brown"
        case .gbcDarkGreen: return "GBC - Dark Green"
        case .gbcGrayscale: return "GBC - Grayscale"
        case .gbcGreen:     return "GBC - Green"
        case .gbcInverted:  return "GBC - Inverted"
        case .gbcOrange:    return "GBC - Orange"
        case .gbcPastelMix: return "GBC - Pastel Mix"
        case .gbcRed:       return "GBC - Red"
        case .gbcYellow:    return "GBC - Yellow"
        }
    }

    var paletteID: String { "gambatte.\(optionValue.replacingOccurrences(of: " ", with: "_"))" }

    var displayName: String {
        switch self {
        case .dmg:          return "DMG Green"
        case .pocket:       return "GB Pocket"
        case .light:        return "GB Light"
        case .gbcBlue:      return "GBC Blue"
        case .gbcBrown:     return "GBC Brown"
        case .gbcDarkBlue:  return "GBC Dark Blue"
        case .gbcDarkBrown: return "GBC Dark Brown"
        case .gbcDarkGreen: return "GBC Dark Green"
        case .gbcGrayscale: return "GBC Grayscale"
        case .gbcGreen:     return "GBC Green"
        case .gbcInverted:  return "Inverted"
        case .gbcOrange:    return "GBC Orange"
        case .gbcPastelMix: return "GBC Pastel Mix"
        case .gbcRed:       return "GBC Red"
        case .gbcYellow:    return "GBC Yellow"
        }
    }

    /// 4-colour swatch [lightest → darkest].
    var previewColors: [PaletteColor] {
        switch self {
        case .dmg:
            return [.init(hex: 0x9BBC0F), .init(hex: 0x8BAC0F), .init(hex: 0x306230), .init(hex: 0x0F380F)]
        case .pocket:
            return [.init(hex: 0xC8C0B0), .init(hex: 0x908880), .init(hex: 0x585048), .init(hex: 0x181010)]
        case .light:
            return [.init(hex: 0xA0C8A0), .init(hex: 0x608060), .init(hex: 0x204020), .init(hex: 0x001000)]
        case .gbcBlue:
            return [.init(hex: 0xD0E8F8), .init(hex: 0x78A8D8), .init(hex: 0x2858A8), .init(hex: 0x001028)]
        case .gbcBrown:
            return [.init(hex: 0xE8C890), .init(hex: 0xB07828), .init(hex: 0x583808), .init(hex: 0x180000)]
        case .gbcDarkBlue:
            return [.init(hex: 0xB0C8E8), .init(hex: 0x506898), .init(hex: 0x183868), .init(hex: 0x000818)]
        case .gbcDarkBrown:
            return [.init(hex: 0xC8A870), .init(hex: 0x886030), .init(hex: 0x402010), .init(hex: 0x100000)]
        case .gbcDarkGreen:
            return [.init(hex: 0x90C890), .init(hex: 0x408840), .init(hex: 0x105010), .init(hex: 0x002000)]
        case .gbcGrayscale:
            return [.init(hex: 0xE8E8E8), .init(hex: 0xA0A0A0), .init(hex: 0x505050), .init(hex: 0x000000)]
        case .gbcGreen:
            return [.init(hex: 0xC8F0A0), .init(hex: 0x70C048), .init(hex: 0x188018), .init(hex: 0x003008)]
        case .gbcInverted:
            return [.init(hex: 0x183800), .init(hex: 0x307030), .init(hex: 0x98B048), .init(hex: 0xE0F0A0)]
        case .gbcOrange:
            return [.init(hex: 0xF8D0A0), .init(hex: 0xE09030), .init(hex: 0x903010), .init(hex: 0x200800)]
        case .gbcPastelMix:
            return [.init(hex: 0xF8E8D0), .init(hex: 0xD0B888), .init(hex: 0x806040), .init(hex: 0x201000)]
        case .gbcRed:
            return [.init(hex: 0xF0C8C8), .init(hex: 0xD07070), .init(hex: 0x980030), .init(hex: 0x300000)]
        case .gbcYellow:
            return [.init(hex: 0xF8F0A0), .init(hex: 0xD8C030), .init(hex: 0x887800), .init(hex: 0x201800)]
        }
    }

    var asCorePalette: CorePalette {
        CorePalette(id: paletteID, displayName: displayName, colors: previewColors)
    }

    static func from(paletteID id: String) -> GambatteLibretroPalette? {
        allCases.first { $0.paletteID == id }
    }

    static func from(optionValue v: String) -> GambatteLibretroPalette? {
        allCases.first { $0.optionValue == v }
    }
}

// MARK: - mGBA palettes

/// Maps to `mgba_gb_colors` core option values (DMG-mode only).
enum MGBALibretroPalette: CaseIterable {
    case dmgGreen
    case dmgGrey
    case gbcBrown
    case gbcBlue
    case gbcDarkBlue
    case gbcDarkBrown
    case gbcDarkGreen
    case gbcGrayscale
    case gbcGreen
    case gbcInverted
    case gbcOrange
    case gbcPastelMix
    case gbcRed
    case gbcYellow
    case grayscale

    var optionValue: String {
        switch self {
        case .dmgGreen:     return "DMG Green"
        case .dmgGrey:      return "DMG Grey"
        case .gbcBrown:     return "GBC Brown"
        case .gbcBlue:      return "GBC - Blue"
        case .gbcDarkBlue:  return "GBC - Dark Blue"
        case .gbcDarkBrown: return "GBC - Dark Brown"
        case .gbcDarkGreen: return "GBC - Dark Green"
        case .gbcGrayscale: return "GBC - Grayscale"
        case .gbcGreen:     return "GBC - Green"
        case .gbcInverted:  return "GBC - Inverted"
        case .gbcOrange:    return "GBC - Orange"
        case .gbcPastelMix: return "GBC - Pastel Mix"
        case .gbcRed:       return "GBC - Red"
        case .gbcYellow:    return "GBC - Yellow"
        case .grayscale:    return "Grayscale"
        }
    }

    var paletteID: String { "mgba.\(optionValue.replacingOccurrences(of: " ", with: "_"))" }

    var displayName: String {
        switch self {
        case .dmgGreen:     return "DMG Green"
        case .dmgGrey:      return "DMG Grey"
        case .gbcBrown:     return "GBC Brown"
        case .gbcBlue:      return "GBC Blue"
        case .gbcDarkBlue:  return "GBC Dark Blue"
        case .gbcDarkBrown: return "GBC Dark Brown"
        case .gbcDarkGreen: return "GBC Dark Green"
        case .gbcGrayscale: return "GBC Grayscale"
        case .gbcGreen:     return "GBC Green"
        case .gbcInverted:  return "Inverted"
        case .gbcOrange:    return "GBC Orange"
        case .gbcPastelMix: return "GBC Pastel Mix"
        case .gbcRed:       return "GBC Red"
        case .gbcYellow:    return "GBC Yellow"
        case .grayscale:    return "Grayscale"
        }
    }

    var previewColors: [PaletteColor] {
        switch self {
        case .dmgGreen:
            return [.init(hex: 0x9BBC0F), .init(hex: 0x8BAC0F), .init(hex: 0x306230), .init(hex: 0x0F380F)]
        case .dmgGrey:
            return [.init(hex: 0xD0D0D0), .init(hex: 0x909090), .init(hex: 0x484848), .init(hex: 0x080808)]
        case .gbcBrown:
            return [.init(hex: 0xE8C890), .init(hex: 0xB07828), .init(hex: 0x583808), .init(hex: 0x180000)]
        case .gbcBlue:
            return [.init(hex: 0xD0E8F8), .init(hex: 0x78A8D8), .init(hex: 0x2858A8), .init(hex: 0x001028)]
        case .gbcDarkBlue:
            return [.init(hex: 0xB0C8E8), .init(hex: 0x506898), .init(hex: 0x183868), .init(hex: 0x000818)]
        case .gbcDarkBrown:
            return [.init(hex: 0xC8A870), .init(hex: 0x886030), .init(hex: 0x402010), .init(hex: 0x100000)]
        case .gbcDarkGreen:
            return [.init(hex: 0x90C890), .init(hex: 0x408840), .init(hex: 0x105010), .init(hex: 0x002000)]
        case .gbcGrayscale:
            return [.init(hex: 0xE8E8E8), .init(hex: 0xA0A0A0), .init(hex: 0x505050), .init(hex: 0x000000)]
        case .gbcGreen:
            return [.init(hex: 0xC8F0A0), .init(hex: 0x70C048), .init(hex: 0x188018), .init(hex: 0x003008)]
        case .gbcInverted:
            return [.init(hex: 0x183800), .init(hex: 0x307030), .init(hex: 0x98B048), .init(hex: 0xE0F0A0)]
        case .gbcOrange:
            return [.init(hex: 0xF8D0A0), .init(hex: 0xE09030), .init(hex: 0x903010), .init(hex: 0x200800)]
        case .gbcPastelMix:
            return [.init(hex: 0xF8E8D0), .init(hex: 0xD0B888), .init(hex: 0x806040), .init(hex: 0x201000)]
        case .gbcRed:
            return [.init(hex: 0xF0C8C8), .init(hex: 0xD07070), .init(hex: 0x980030), .init(hex: 0x300000)]
        case .gbcYellow:
            return [.init(hex: 0xF8F0A0), .init(hex: 0xD8C030), .init(hex: 0x887800), .init(hex: 0x201800)]
        case .grayscale:
            return [.init(hex: 0xE8E8E8), .init(hex: 0xA0A0A0), .init(hex: 0x505050), .init(hex: 0x000000)]
        }
    }

    var asCorePalette: CorePalette {
        CorePalette(id: paletteID, displayName: displayName, colors: previewColors)
    }

    static func from(paletteID id: String) -> MGBALibretroPalette? {
        allCases.first { $0.paletteID == id }
    }

    static func from(optionValue v: String) -> MGBALibretroPalette? {
        allCases.first { $0.optionValue == v }
    }
}

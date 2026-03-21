//
//  PVPokeMiniEmulatorCore+PaletteProviding.swift
//  PVPokeMini
//
//  Part of #2649 — Custom Palette System
//  Sub-task 4: PokeMini PaletteProviding adoption
//

import PVCoreBridge
import PVPokeMiniOptions
import PVLogging
@preconcurrency import libpokemini

// MARK: - PaletteProviding

extension PVPokeMiniEmulatorCore: PaletteProviding {

    public var availablePalettes: [CorePalette] {
        PokeMiniPalette.allCases.map(\.asCorePalette)
    }

    public var currentPaletteID: String {
        let index = Int(CommandLine.palette)
        return PokeMiniPalette(rawValue: index)?.paletteID ?? PokeMiniPalette.default.paletteID
    }

    public func selectPalette(id: String) {
        guard let palette = PokeMiniPalette.allCases.first(where: { $0.paletteID == id }) else {
            WLOG("PokeMini: unknown palette id '\(id)'")
            return
        }
        CommandLine.palette = Int32(palette.rawValue)
        PokeMini_VideoPalette_Index(CommandLine.palette, nil, CommandLine.lcdcontrast, CommandLine.lcdbright)
        PokeMini_ApplyChanges()
    }
}

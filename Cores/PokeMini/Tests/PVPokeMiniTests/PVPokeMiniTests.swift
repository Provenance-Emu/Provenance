//
//  PVPokeMiniTests.swift
//  PVPokeMini
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
@testable import libpokemini
@testable import PokeMiniC
@testable import PVPokeMini
@testable import PVPokeMiniBridge
@testable import PVPokeMiniOptions

struct CoreTests {
    @Test func testAllocDealloc() async throws {
        let core = PVPokeMiniEmulatorCore()
        #expect(core != nil)
    }
}

// MARK: - PokeMiniPalette Tests

struct PokeMiniPaletteTests {

    @Test func allCasesHaveTwoPreviewColors() {
        for palette in PokeMiniPalette.allCases {
            #expect(palette.previewColors.count == 2,
                    "Palette \(palette.paletteID) should have 2 preview colors")
        }
    }

    @Test func paletteIDsAreUnique() {
        let ids = PokeMiniPalette.allCases.map(\.paletteID)
        let unique = Set(ids)
        #expect(ids.count == unique.count, "All palette IDs must be unique")
    }

    @Test func displayNamesAreNonEmpty() {
        for palette in PokeMiniPalette.allCases {
            #expect(!palette.displayName.isEmpty,
                    "Palette \(palette.paletteID) must have a non-empty display name")
        }
    }

    @Test func allCasesConvertToCorePalette() {
        for palette in PokeMiniPalette.allCases {
            let cp = palette.asCorePalette
            #expect(cp.id == palette.paletteID)
            #expect(cp.displayName == palette.displayName)
            #expect(cp.colors.count == 2)
        }
    }

    @Test func rawValuesMappedToCorrectIDs() {
        #expect(PokeMiniPalette(rawValue: 0)?.paletteID == "defaultGreen")
        #expect(PokeMiniPalette(rawValue: 2)?.paletteID == "monochrome")
        #expect(PokeMiniPalette(rawValue: 13)?.paletteID == "monochromeVector")
    }

    @Test func unknownRawValueReturnsNil() {
        #expect(PokeMiniPalette(rawValue: 99) == nil)
    }

    @Test func defaultPaletteIsDefaultGreen() {
        #expect(PokeMiniPalette.default == .defaultGreen)
    }

    @Test func totalPaletteCount() {
        #expect(PokeMiniPalette.allCases.count == 14)
    }
}

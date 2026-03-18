//
//  PaletteTests.swift
//  PVLibRetroTests
//
//  Tests for GambatteLibretroPalette and MGBALibretroPalette mapping logic.
//  Covers round-trip paletteID ↔ optionValue and default fallback behaviour.
//

import Testing
@testable import PVLibRetro

// MARK: - Gambatte palette tests

struct GambattePaletteTests {

    /// Every palette must survive a paletteID → from(paletteID:) → optionValue →
    /// from(optionValue:) → paletteID round-trip without data loss.
    @Test func roundTrip_paletteID_optionValue() {
        for palette in GambatteLibretroPalette.allCases {
            let id = palette.paletteID
            guard let recovered = GambatteLibretroPalette.from(paletteID: id) else {
                Issue.record("from(paletteID:) returned nil for \(id)")
                continue
            }
            #expect(recovered == palette, "paletteID round-trip failed for \(palette)")

            let optVal = recovered.optionValue
            guard let fromOpt = GambatteLibretroPalette.from(optionValue: optVal) else {
                Issue.record("from(optionValue:) returned nil for \(optVal)")
                continue
            }
            #expect(fromOpt == palette, "optionValue round-trip failed for \(palette)")
        }
    }

    /// paletteIDs must be unique across the set — no two cases should share an ID.
    @Test func paletteIDs_areUnique() {
        let ids = GambatteLibretroPalette.allCases.map(\.paletteID)
        let unique = Set(ids)
        #expect(ids.count == unique.count, "Duplicate paletteIDs detected in GambatteLibretroPalette")
    }

    /// optionValues must be unique — each libretro option string is distinct.
    @Test func optionValues_areUnique() {
        let vals = GambatteLibretroPalette.allCases.map(\.optionValue)
        let unique = Set(vals)
        #expect(vals.count == unique.count, "Duplicate optionValues detected in GambatteLibretroPalette")
    }

    /// Looking up an unknown paletteID must return nil (no crash, no default).
    @Test func from_unknownPaletteID_returnsNil() {
        let result = GambatteLibretroPalette.from(paletteID: "gambatte.NOT_A_REAL_PALETTE")
        #expect(result == nil, "Expected nil for unknown paletteID")
    }

    /// Looking up an unknown optionValue must return nil.
    @Test func from_unknownOptionValue_returnsNil() {
        let result = GambatteLibretroPalette.from(optionValue: "GBC - NonExistent")
        #expect(result == nil, "Expected nil for unknown optionValue")
    }

    /// The DMG palette must map to the canonical libretro option string used by gambatte.
    @Test func dmg_optionValue_isCanonical() {
        #expect(GambatteLibretroPalette.dmg.optionValue == "GB - DMG")
    }
}

// MARK: - mGBA palette tests

struct MGBAPaletteTests {

    /// Every palette must survive a paletteID → from(paletteID:) → optionValue →
    /// from(optionValue:) → paletteID round-trip without data loss.
    @Test func roundTrip_paletteID_optionValue() {
        for palette in MGBALibretroPalette.allCases {
            let id = palette.paletteID
            guard let recovered = MGBALibretroPalette.from(paletteID: id) else {
                Issue.record("from(paletteID:) returned nil for \(id)")
                continue
            }
            #expect(recovered == palette, "paletteID round-trip failed for \(palette)")

            let optVal = recovered.optionValue
            guard let fromOpt = MGBALibretroPalette.from(optionValue: optVal) else {
                Issue.record("from(optionValue:) returned nil for \(optVal)")
                continue
            }
            #expect(fromOpt == palette, "optionValue round-trip failed for \(palette)")
        }
    }

    /// paletteIDs must be unique across the set.
    @Test func paletteIDs_areUnique() {
        let ids = MGBALibretroPalette.allCases.map(\.paletteID)
        let unique = Set(ids)
        #expect(ids.count == unique.count, "Duplicate paletteIDs detected in MGBALibretroPalette")
    }

    /// optionValues must be unique.
    @Test func optionValues_areUnique() {
        let vals = MGBALibretroPalette.allCases.map(\.optionValue)
        let unique = Set(vals)
        #expect(vals.count == unique.count, "Duplicate optionValues detected in MGBALibretroPalette")
    }

    /// Looking up an unknown paletteID must return nil.
    @Test func from_unknownPaletteID_returnsNil() {
        let result = MGBALibretroPalette.from(paletteID: "mgba.NOT_A_REAL_PALETTE")
        #expect(result == nil, "Expected nil for unknown paletteID")
    }

    /// Looking up an unknown optionValue must return nil.
    @Test func from_unknownOptionValue_returnsNil() {
        let result = MGBALibretroPalette.from(optionValue: "NonExistent Palette")
        #expect(result == nil, "Expected nil for unknown optionValue")
    }

    /// The DMG Green palette must map to the canonical libretro option string used by mGBA.
    @Test func dmgGreen_optionValue_isCanonical() {
        #expect(MGBALibretroPalette.dmgGreen.optionValue == "DMG Green")
    }
}

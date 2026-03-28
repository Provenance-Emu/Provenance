//
//  Test.swift
//  PVGambatteTests
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
@testable import PVGambatte
import PVGambatteOptions
import PVCoreBridge

// MARK: - PVGBEmulatorCore basic tests

struct PVGambatteTests {

    @Test func coreInitializes() async throws {
        // Verify the core can be instantiated without crashing.
        // systemIdentifier is populated when a ROM is loaded, not at init time.
        let core = PVGBEmulatorCore()
        // The core should expose at least one palette immediately after init (DMG mode).
        let palettes = core.availablePalettes
        #expect(!palettes.isEmpty, "Core should expose available palettes after init")
    }
}

// MARK: - GBPalette data model tests (pure Swift, no bridge required)

struct GBPaletteTests {

    @Test func allCasesHaveFourPreviewColors() {
        for p in GBPalette.allCases {
            #expect(p.previewColors.count == 4,
                    "GBPalette.\(p) should have 4 preview colors, got \(p.previewColors.count)")
        }
    }

    @Test func allCasesHaveNonEmptyDisplayNames() {
        for p in GBPalette.allCases {
            #expect(!p.displayName.isEmpty, "GBPalette.\(p) has an empty displayName")
        }
    }

    @Test func paletteIDsAreUnique() {
        let ids = GBPalette.allCases.map(\.paletteID)
        #expect(ids.count == Set(ids).count, "Duplicate GBPalette ids detected")
    }

    @Test func corePaletteConversionPreservesData() {
        for p in GBPalette.allCases {
            let cp = p.asCorePalette
            #expect(cp.id == p.paletteID)
            #expect(cp.displayName == p.displayName)
            #expect(cp.colors.count == p.previewColors.count)
        }
    }

    @Test func previewColorValuesAreNormalized() {
        for p in GBPalette.allCases {
            for c in p.previewColors {
                #expect(c.red   >= 0 && c.red   <= 1, "red channel out of range for \(p)")
                #expect(c.green >= 0 && c.green <= 1, "green channel out of range for \(p)")
                #expect(c.blue  >= 0 && c.blue  <= 1, "blue channel out of range for \(p)")
            }
        }
    }

    @Test func hexInitMatchesExpectedApproximately() {
        // 0xFF0000 ≈ red=1.0, green=0.0, blue=0.0
        let red = PaletteColor(hex: 0xFF0000)
        #expect(abs(red.red - 1.0) < 0.01)
        #expect(abs(red.green) < 0.01)
        #expect(abs(red.blue) < 0.01)
    }
}

// MARK: - CoreRetroAchievements behaviour tests (no ROM loaded, no HAVE_RCHEEVOS)

struct RetroAchievementsTests {

    /// prepareAchievements must complete (not hang) when HAVE_RCHEEVOS is disabled
    /// or when no rc_client has been initialised (pre-ROM-load state).
    @Test func prepareAchievementsCompletesWithoutRcheevos() async {
        let core = PVGBEmulatorCore()
        // Should return immediately — no rc_client, completion fires synchronously.
        await core.prepareAchievements(gameHash: "00000000000000000000000000000000")
        // If we reach here the call didn't hang.
    }

    /// achievementMemoryRegions must return an empty array when no ROM is loaded
    /// (wramBasePtr is nil because Gambatte has not loaded a ROM yet).
    @Test func achievementMemoryRegionsEmptyBeforeROMLoad() {
        let core = PVGBEmulatorCore()
        let regions = core.achievementMemoryRegions()
        #expect(regions.isEmpty, "Expected no memory regions before a ROM is loaded")
    }
}

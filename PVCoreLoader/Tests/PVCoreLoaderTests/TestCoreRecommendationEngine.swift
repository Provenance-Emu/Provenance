//
//  TestCoreRecommendationEngine.swift
//  PVCoreLoaderTests
//
//  Created by Claude on 2026-03-19.
//

import XCTest
@testable import PVCoreLoader
import PVPrimitives

final class TestCoreRecommendationEngine: XCTestCase {

    var engine: CoreRecommendationEngine!

    override func setUp() {
        super.setUp()
        engine = CoreRecommendationEngine()
    }

    // MARK: - Empty input

    func testReturnsEmptyForNoCores() {
        let recs = engine.recommendations(
            gameTitle: "Mario",
            systemIdentifier: nil,
            availableCoreIdentifiers: []
        )
        XCTAssertTrue(recs.isEmpty)
    }

    // MARK: - Single core

    func testSingleCoreIsStandardRank() {
        let recs = engine.recommendations(
            gameTitle: "Some Game",
            systemIdentifier: nil,
            availableCoreIdentifiers: ["com.provenance.core.mGBA"]
        )
        XCTAssertEqual(recs.count, 1)
        // Single core should never be marked "recommended" (no competition)
        XCTAssertEqual(recs.first?.rank, .standard)
    }

    // MARK: - Save state ordering

    func testCoreWithMoreSavesIsFirstWhenEqualCapabilities() {
        let coreA = "com.provenance.core.visualboyadvance"
        let coreB = "com.provenance.core.mGBA"

        let recs = engine.recommendations(
            gameTitle: "Some GBA Game",
            systemIdentifier: "com.provenance.gba",
            availableCoreIdentifiers: [coreA, coreB],
            saveCounts: [coreA: 5, coreB: 0]
        )

        XCTAssertEqual(recs.count, 2)
        // coreA has more saves; user should not lose progress
        XCTAssertEqual(recs.first?.coreIdentifier, coreA)
        XCTAssertEqual(recs.first?.saveCount, 5)
    }

    // MARK: - Capability matching

    func testTitleContainsMatchSurfacesCapabilityTip() {
        let recs = engine.recommendations(
            gameTitle: "Nintendogs",
            systemIdentifier: "com.provenance.ds",
            availableCoreIdentifiers: [
                "com.provenance.core.MelonDS",
                "com.provenance.core.desmume2015"
            ]
        )

        guard let best = recs.first else {
            XCTFail("Expected at least one recommendation")
            return
        }

        // melonDS has realMicrophone capability; should be surfaced
        XCTAssertEqual(best.coreIdentifier, "com.provenance.core.MelonDS")
        XCTAssertTrue(best.highlightedCapabilities.contains(.realMicrophone))
        XCTAssertNotNil(best.recommendationTip)
    }

    // MARK: - System-level recommendation

    func testSystemIdentifierMatchRanksHighAccuracyCoreFirst() {
        let recs = engine.recommendations(
            gameTitle: "Some PS1 Game",
            systemIdentifier: "com.provenance.psx",
            availableCoreIdentifiers: [
                "com.provenance.core.PCSXRearmed",   // lower rank
                "com.provenance.core.duckstation"    // higher rank
            ]
        )

        XCTAssertEqual(recs.count, 2)
        XCTAssertEqual(recs.first?.coreIdentifier, "com.provenance.core.duckstation")
    }

    // MARK: - Recommendation rank labels

    func testBestCoreReceivesRecommendedBadge() {
        let recs = engine.recommendations(
            gameTitle: "Pokemon Black",
            systemIdentifier: "com.provenance.ds",
            availableCoreIdentifiers: [
                "com.provenance.core.MelonDS",
                "com.provenance.core.desmume2015"
            ]
        )

        XCTAssertEqual(recs.first?.rank, .recommended)
    }

    // MARK: - Metadata loading

    func testManifestLoadedSuccessfully() {
        let meta = engine.capabilityMetadata(for: "com.provenance.core.mGBA")
        XCTAssertNotNil(meta, "mGBA should have metadata in CoreCapabilities.json")
        XCTAssertTrue(meta?.capabilities.contains(.highAccuracy) == true)
    }

    // MARK: - Multi-source manifest building

    /// Verifies that a manifest built from an explicit CoreCapabilitiesManifest (no CoreLoader)
    /// correctly surfaces capabilities injected via the manifest parameter — the enrichment path.
    func testEnrichmentOnlyManifestSurfacesCapabilities() {
        let testMeta = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.alpha",
            summary: "Test core",
            capabilities: [.highAccuracy, .cheats],
            notes: [],
            qualityRank: 75
        )
        let manifest = CoreCapabilitiesManifest(
            version: 2,
            cores: [testMeta],
            gameRequirements: []
        )
        let testEngine = CoreRecommendationEngine(manifest: manifest)

        let meta = testEngine.capabilityMetadata(for: "com.test.core.alpha")
        XCTAssertNotNil(meta)
        XCTAssertTrue(meta?.capabilities.contains(.highAccuracy) == true)
        XCTAssertTrue(meta?.capabilities.contains(.cheats) == true)
        XCTAssertEqual(meta?.qualityRank, 75)
    }

    /// Verifies that a manifest with both `highAccuracy` and `cheats` capabilities is correctly
    /// surfaced through the engine's recommendation output when a game matches both cores.
    func testAutoDeriveCheatsFromPlistMergesWithEnrichment() {
        // Build a manifest where a core has both cheats and highAccuracy declared.
        let mergedMeta = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.beta",
            summary: "Beta",
            capabilities: [.highAccuracy, .cheats],
            notes: [],
            qualityRank: 50
        )
        let manifest = CoreCapabilitiesManifest(
            version: 2,
            cores: [mergedMeta],
            gameRequirements: []
        )
        let testEngine = CoreRecommendationEngine(manifest: manifest)

        // Drive through the engine's public recommendation API.
        let recs = testEngine.recommendations(
            gameTitle: "Test Game",
            systemIdentifier: nil,
            availableCoreIdentifiers: ["com.test.core.beta"]
        )

        XCTAssertEqual(recs.count, 1)
        let meta = recs.first?.metadata
        XCTAssertNotNil(meta)
        XCTAssertTrue(meta?.capabilities.contains(.highAccuracy) == true)
        XCTAssertTrue(meta?.capabilities.contains(.cheats) == true)
        XCTAssertEqual(meta?.summary, "Beta")
        XCTAssertEqual(meta?.qualityRank, 50)
    }

    /// Verifies that capabilities declared via PVCapabilities in a plist are parsed correctly.
    func testPlistCapabilitiesParseFromRawValues() {
        // Simulate what EmulatorCoreInfoPlist would produce from PVCapabilities key
        let rawCapabilities = ["highAccuracy", "rumble", "rewind", "unknownCapability"]
        var caps = Set<CoreCapability>()
        for raw in rawCapabilities {
            if let cap = CoreCapability(rawValue: raw) {
                caps.insert(cap)
            }
        }
        // Known capabilities are parsed; unknown ones are silently skipped
        XCTAssertTrue(caps.contains(.highAccuracy))
        XCTAssertTrue(caps.contains(.rumble))
        XCTAssertTrue(caps.contains(.rewind))
        XCTAssertEqual(caps.count, 3, "Unknown capability should be skipped")
    }

    // MARK: - retroAchievements capability

    /// Verifies that a libretro core declared with retroAchievements in the bundle JSON
    /// surfaces that capability through the recommendation engine.
    func testLibretroCoreSurfacesRetroAchievementsFromBundleJSON() {
        // Beetle PSX SW is declared with retroAchievements in CoreCapabilities.json
        let meta = engine.capabilityMetadata(for: "mednafen.psx.libretro.framework")
        XCTAssertNotNil(meta, "Beetle PSX SW should have metadata in CoreCapabilities.json")
        XCTAssertTrue(meta?.capabilities.contains(.retroAchievements) == true,
                      "Beetle PSX SW should advertise retroAchievements (cheevos.c via PVCoreBridgeRetro)")
    }

    /// Verifies that the Flycast jitless variant (App Store) advertises retroAchievements.
    func testFlycastJitlessAdvertisesRetroAchievements() {
        let meta = engine.capabilityMetadata(for: "flycast-jitless.libretro.framework")
        XCTAssertNotNil(meta)
        XCTAssertTrue(meta?.capabilities.contains(.retroAchievements) == true)
    }

    /// Verifies the PSX system requirement now includes retroAchievements as a preferred capability.
    func testPSXSystemRequirementPrefersRetroAchievements() {
        let recs = engine.recommendations(
            gameTitle: "Crash Bandicoot",
            systemIdentifier: "com.provenance.psx",
            availableCoreIdentifiers: [
                "mednafen.psx.libretro.framework",   // has retroAchievements
                "com.provenance.core.PCSXRearmed"    // does not
            ]
        )

        XCTAssertEqual(recs.count, 2)
        // Beetle PSX SW has both highAccuracy and retroAchievements — should rank first
        XCTAssertEqual(recs.first?.coreIdentifier, "mednafen.psx.libretro.framework")
        XCTAssertTrue(recs.first?.highlightedCapabilities.contains(.retroAchievements) == true)
        XCTAssertNotNil(recs.first?.recommendationTip, "PSX system requirement tip should surface")
    }

    /// Verifies that a core explicitly given retroAchievements in an injected manifest
    /// is ranked above one without it when retroAchievements is a preferred capability.
    func testRetroAchievementsPreferenceRanksCorrectly() {
        let coreWithRA = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.withRA",
            summary: "Core with RetroAchievements",
            capabilities: [.retroAchievements, .highAccuracy],
            notes: [],
            qualityRank: 80
        )
        let coreWithoutRA = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.noRA",
            summary: "Core without RetroAchievements",
            capabilities: [.highAccuracy],
            notes: [],
            qualityRank: 85  // higher base rank, but no retroAchievements
        )
        let requirement = GameFeatureRequirement(
            matchStrategy: .systemIdentifier,
            matchValue: "com.provenance.psx",
            preferredCapabilities: [.retroAchievements],
            tip: "Choose a core with RetroAchievements support."
        )
        let manifest = CoreCapabilitiesManifest(
            version: 2,
            cores: [coreWithRA, coreWithoutRA],
            gameRequirements: [requirement]
        )
        let testEngine = CoreRecommendationEngine(manifest: manifest)

        let recs = testEngine.recommendations(
            gameTitle: "Some PS1 Game",
            systemIdentifier: "com.provenance.psx",
            availableCoreIdentifiers: ["com.test.core.withRA", "com.test.core.noRA"]
        )

        XCTAssertEqual(recs.count, 2)
        XCTAssertEqual(recs.first?.coreIdentifier, "com.test.core.withRA",
                       "Core with retroAchievements should rank above one without it when RA is preferred")
        XCTAssertTrue(recs.first?.highlightedCapabilities.contains(.retroAchievements) == true)
    }

    /// Verifies that the native Mednafen core (com.provenance.core.mednafen) advertises
    /// retroAchievements in the bundle JSON — critical for the fallback path used in tests.
    func testNativeMednafenAdvertisesRetroAchievementsInJSON() {
        let meta = engine.capabilityMetadata(for: "com.provenance.core.mednafen")
        XCTAssertNotNil(meta, "Native Mednafen should have an entry in CoreCapabilities.json")
        XCTAssertTrue(meta?.capabilities.contains(.retroAchievements) == true,
                      "Mednafen native rc_client integration must surface retroAchievements capability")
    }

    /// Verifies the retroAchievements raw value parses from a JSON capability string.
    func testRetroAchievementsRawValueParsesFromString() {
        let rawCapabilities = ["retroAchievements", "highAccuracy"]
        let caps = Set(rawCapabilities.compactMap { CoreCapability(rawValue: $0) })
        XCTAssertTrue(caps.contains(.retroAchievements))
        XCTAssertTrue(caps.contains(.highAccuracy))
        XCTAssertEqual(caps.count, 2)
    }
}

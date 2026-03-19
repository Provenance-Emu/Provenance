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
}

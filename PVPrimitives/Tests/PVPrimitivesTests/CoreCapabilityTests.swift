// CoreCapabilityTests.swift
// PVPrimitivesTests
//
// Created by Provenance Emu on 2026-03-27.
// Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVPrimitives

// MARK: - CoreCapability enum tests

final class CoreCapabilityTests: XCTestCase {

    // MARK: - retroAchievements raw value

    func testRetroAchievementsRawValue() {
        XCTAssertEqual(CoreCapability.retroAchievements.rawValue, "retroAchievements")
    }

    func testRetroAchievementsDecodesFromRawValue() {
        XCTAssertEqual(CoreCapability(rawValue: "retroAchievements"), .retroAchievements)
    }

    func testUnknownRawValueReturnsNil() {
        XCTAssertNil(CoreCapability(rawValue: "achievementBadges"))
    }

    // MARK: - displayName

    func testRetroAchievementsDisplayName() {
        XCTAssertEqual(CoreCapability.retroAchievements.displayName, "RetroAchievements")
    }

    // MARK: - sfSymbol

    func testRetroAchievementsSFSymbol() {
        XCTAssertEqual(CoreCapability.retroAchievements.sfSymbol, "trophy.fill")
    }

    // MARK: - isRequirement

    func testRetroAchievementsIsNotARequirement() {
        XCTAssertFalse(CoreCapability.retroAchievements.isRequirement)
    }

    func testRequiresJITIsARequirement() {
        XCTAssertTrue(CoreCapability.requiresJIT.isRequirement)
    }

    func testRequiresBIOSIsARequirement() {
        XCTAssertTrue(CoreCapability.requiresBIOS.isRequirement)
    }

    // MARK: - CaseIterable

    func testRetroAchievementsInAllCases() {
        XCTAssertTrue(CoreCapability.allCases.contains(.retroAchievements))
    }

    // MARK: - All cases have display names and SF symbols

    func testAllCasesHaveNonEmptyDisplayNames() {
        for cap in CoreCapability.allCases {
            XCTAssertFalse(cap.displayName.isEmpty, "\(cap) has empty displayName")
        }
    }

    func testAllCasesHaveNonEmptySFSymbols() {
        for cap in CoreCapability.allCases {
            XCTAssertFalse(cap.sfSymbol.isEmpty, "\(cap) has empty sfSymbol")
        }
    }

    // MARK: - Codable round-trip via CoreCapabilityMetadata

    func testRetroAchievementsEncodesDecodesViaMetadata() throws {
        let meta = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core",
            summary: "Test",
            capabilities: [.retroAchievements, .highAccuracy],
            notes: [],
            qualityRank: 90
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(CoreCapabilityMetadata.self, from: data)

        XCTAssertTrue(decoded.capabilities.contains(.retroAchievements))
        XCTAssertTrue(decoded.capabilities.contains(.highAccuracy))
        XCTAssertEqual(decoded.qualityRank, 90)
    }

    func testUnknownCapabilityStringIsDroppedDuringDecode() throws {
        // Simulates a future JSON with a capability this version of the app doesn't know about.
        let json = """
        {
            "coreIdentifier": "com.test.core",
            "summary": "Test",
            "capabilities": ["retroAchievements", "futureCapabilityUnknown"],
            "notes": [],
            "qualityRank": 80
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CoreCapabilityMetadata.self, from: data)

        XCTAssertTrue(decoded.capabilities.contains(.retroAchievements))
        XCTAssertEqual(decoded.capabilities.count, 1, "Unknown capability should be silently dropped")
    }

    // MARK: - CoreCapabilitiesManifest JSON round-trip

    func testManifestDecodesRetroAchievementsCapability() throws {
        let json = """
        {
            "version": 2,
            "cores": [
                {
                    "coreIdentifier": "some.libretro.framework",
                    "summary": "Some libretro core with RetroAchievements.",
                    "capabilities": ["highAccuracy", "retroAchievements"],
                    "notes": ["RetroArch integration"],
                    "qualityRank": 88
                }
            ],
            "gameRequirements": [
                {
                    "matchStrategy": "systemIdentifier",
                    "matchValue": "com.provenance.psx",
                    "preferredCapabilities": ["highAccuracy", "retroAchievements"],
                    "tip": "Prefer a core with RetroAchievements support."
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(CoreCapabilitiesManifest.self, from: data)

        let core = manifest.metadata(for: "some.libretro.framework")
        XCTAssertNotNil(core)
        XCTAssertTrue(core?.capabilities.contains(.retroAchievements) == true)
        XCTAssertTrue(core?.capabilities.contains(.highAccuracy) == true)

        let req = manifest.gameRequirements.first
        XCTAssertTrue(req?.preferredCapabilities.contains(.retroAchievements) == true)
    }
}

//
//  RumblePresetTests.swift
//  PVPrimitivesTests
//
//  Unit tests for RumblePreset: encode/decode round-trip, reidentify, toSystemProfile.
//

import XCTest
@testable import PVPrimitives

final class RumblePresetTests: XCTestCase {

    // MARK: - Basic construction

    func testInitClampsValues() {
        let preset = RumblePreset(
            name: "Test",
            lowFrequencyScale: 1.5,   // should clamp to 1.0
            highFrequencyScale: -0.1, // should clamp to 0.0
            sharpness: 2.0            // should clamp to 1.0
        )
        XCTAssertEqual(preset.lowFrequencyScale, 1.0)
        XCTAssertEqual(preset.highFrequencyScale, 0.0)
        XCTAssertEqual(preset.sharpness, 1.0)
    }

    func testDefaultValues() {
        let preset = RumblePreset(name: "Default")
        XCTAssertEqual(preset.lowFrequencyScale, 0.8)
        XCTAssertEqual(preset.highFrequencyScale, 0.6)
        XCTAssertEqual(preset.sharpness, 0.5)
        XCTAssertEqual(preset.minBurstDuration, 0.03)
        XCTAssertEqual(preset.version, 1)
    }

    // MARK: - JSON round-trip

    func testEncodeDecodeRoundTrip() throws {
        let original = RumblePreset(
            name: "Round-trip Test",
            lowFrequencyScale: 0.75,
            highFrequencyScale: 0.45,
            sharpness: 0.2,
            minBurstDuration: 0.05
        )
        let data = try original.jsonData()
        let decoded = try RumblePreset.from(jsonData: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.lowFrequencyScale, original.lowFrequencyScale, accuracy: 0.001)
        XCTAssertEqual(decoded.highFrequencyScale, original.highFrequencyScale, accuracy: 0.001)
        XCTAssertEqual(decoded.sharpness, original.sharpness, accuracy: 0.001)
        XCTAssertEqual(decoded.minBurstDuration, original.minBurstDuration, accuracy: 0.0001)
    }

    func testFromInvalidDataThrows() {
        let bad = Data("not json".utf8)
        XCTAssertThrowsError(try RumblePreset.from(jsonData: bad))
    }

    // MARK: - Reidentified

    func testReidentifiedHasNewUUID() {
        let original = RumblePreset(name: "Original")
        let copy = original.reidentified()
        XCTAssertNotEqual(copy.id, original.id, "reidentified() should produce a fresh UUID")
        XCTAssertEqual(copy.name, original.name)
        XCTAssertEqual(copy.lowFrequencyScale, original.lowFrequencyScale)
    }

    // MARK: - toSystemProfile

    func testToSystemProfilePreservesValues() {
        let preset = RumblePreset(
            name: "Custom",
            lowFrequencyScale: 0.9,
            highFrequencyScale: 0.3,
            sharpness: 0.15
        )
        let profile = preset.toSystemProfile(rumbleType: .dualMotor)
        XCTAssertEqual(profile.lowFrequencyScale, 0.9, accuracy: 0.001)
        XCTAssertEqual(profile.highFrequencyScale, 0.3, accuracy: 0.001)
        XCTAssertEqual(profile.sharpness, 0.15, accuracy: 0.001)
        XCTAssertEqual(profile.rumbleType, .dualMotor)
    }

    func testToSystemProfileDefaultRumbleType() {
        let preset = RumblePreset(name: "Generic")
        let profile = preset.toSystemProfile()
        XCTAssertEqual(profile.rumbleType, .singleMotor)
    }

    // MARK: - Built-in presets

    func testBuiltInsNotEmpty() {
        XCTAssertFalse(RumblePreset.builtIns.isEmpty)
    }

    func testBuiltInsHaveUniqueNames() {
        let names = RumblePreset.builtIns.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "All built-in preset names should be unique")
    }

    func testBuiltInFromProfile_n64() throws {
        let preset = try XCTUnwrap(RumblePreset.builtIns.first { $0.name == "N64 Rumble Pak" })
        XCTAssertEqual(preset.lowFrequencyScale, RumbleSystemProfile.n64RumblePak.lowFrequencyScale, accuracy: 0.001)
    }

    // MARK: - Codable stability

    func testVersionIsAlways1() throws {
        let preset = RumblePreset(name: "v1")
        let data = try preset.jsonData()
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
    }

    func testJsonContainsExpectedKeys() throws {
        let preset = RumblePreset(name: "KeyTest")
        let data = try preset.jsonData()
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let requiredKeys = ["id", "name", "version", "lowFrequencyScale", "highFrequencyScale", "sharpness", "minBurstDuration"]
        for key in requiredKeys {
            XCTAssertNotNil(json[key], "Missing key: \(key)")
        }
    }
}

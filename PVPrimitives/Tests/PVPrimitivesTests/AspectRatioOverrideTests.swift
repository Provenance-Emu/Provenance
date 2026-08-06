// AspectRatioOverrideTests.swift
// PVPrimitivesTests
//
// Created by Provenance Emu on 2026-04-03.
// Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVPrimitives

final class AspectRatioOverrideTests: XCTestCase {

    // MARK: - Raw values

    func testAutoRawValue() {
        XCTAssertEqual(AspectRatioOverride.auto.rawValue, "auto")
    }

    func testRatio4_3RawValue() {
        XCTAssertEqual(AspectRatioOverride.ratio_4_3.rawValue, "4:3")
    }

    func testRatio16_9RawValue() {
        XCTAssertEqual(AspectRatioOverride.ratio_16_9.rawValue, "16:9")
    }

    func testRatio1_1RawValue() {
        XCTAssertEqual(AspectRatioOverride.ratio_1_1.rawValue, "1:1")
    }

    func testRatio8_7RawValue() {
        XCTAssertEqual(AspectRatioOverride.ratio_8_7.rawValue, "8:7")
    }

    func testStretchRawValue() {
        XCTAssertEqual(AspectRatioOverride.stretch.rawValue, "stretch")
    }

    // MARK: - CaseIterable

    func testAllCasesCount() {
        XCTAssertEqual(AspectRatioOverride.allCases.count, 6)
    }

    func testAllCasesContainsAuto() {
        XCTAssertTrue(AspectRatioOverride.allCases.contains(.auto))
    }

    // MARK: - aspectRatioValue

    func testAutoAspectRatioValueIsNil() {
        XCTAssertNil(AspectRatioOverride.auto.aspectRatioValue)
    }

    func testStretchAspectRatioValueIsNil() {
        XCTAssertNil(AspectRatioOverride.stretch.aspectRatioValue)
    }

    func testRatio4_3Value() {
        XCTAssertEqual(AspectRatioOverride.ratio_4_3.aspectRatioValue, 4.0 / 3.0, accuracy: 0.0001)
    }

    func testRatio16_9Value() {
        XCTAssertEqual(AspectRatioOverride.ratio_16_9.aspectRatioValue, 16.0 / 9.0, accuracy: 0.0001)
    }

    func testRatio1_1Value() {
        XCTAssertEqual(AspectRatioOverride.ratio_1_1.aspectRatioValue, 1.0, accuracy: 0.0001)
    }

    func testRatio8_7Value() {
        XCTAssertEqual(AspectRatioOverride.ratio_8_7.aspectRatioValue, 8.0 / 7.0, accuracy: 0.0001)
    }

    // MARK: - isWidescreen

    func testOnly16_9IsWidescreen() {
        for override in AspectRatioOverride.allCases {
            if override == .ratio_16_9 {
                XCTAssertTrue(override.isWidescreen, "\(override) should be widescreen")
            } else {
                XCTAssertFalse(override.isWidescreen, "\(override) should not be widescreen")
            }
        }
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for override in AspectRatioOverride.allCases {
            let data = try encoder.encode(override)
            let decoded = try decoder.decode(AspectRatioOverride.self, from: data)
            XCTAssertEqual(decoded, override, "Codable round-trip failed for \(override)")
        }
    }

    // MARK: - displayName

    func testAutoDisplayName() {
        XCTAssertEqual(AspectRatioOverride.auto.displayName, "Auto")
    }

    func testStretchDisplayName() {
        XCTAssertEqual(AspectRatioOverride.stretch.displayName, "Stretch")
    }

    // MARK: - description

    func testDescriptionMatchesDisplayName() {
        for override in AspectRatioOverride.allCases {
            XCTAssertEqual(override.description, override.displayName)
        }
    }
}

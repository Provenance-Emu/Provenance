//
//  CoreOptionsScopedResetTests.swift
//  PVCoreBridgeTests
//
//  Created by Claude on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@testable import PVCoreBridge
import XCTest

// MARK: - Minimal test double

/// A minimal CoreOptional conformer used exclusively for unit-testing the
/// per-game scoped-reset helpers.  It has two options:
///   - `video.fullscreen` (Bool, default true)
///   - `audio.volume`    (range 0–100, default 50)
private enum MockCore: CoreOptional {
    static let options: [CoreOption] = [
        .bool(
            CoreOptionValueDisplay(title: "video.fullscreen", description: nil),
            defaultValue: true
        ),
        .range(
            CoreOptionValueDisplay(title: "audio.volume", description: nil),
            range: CoreOptionRange(min: 0, max: 100),
            defaultValue: 50
        )
    ]
}

// MARK: - Helpers

private extension MockCore {
    static var fullscreenOption: CoreOption { options[0] }
    static var volumeOption:     CoreOption { options[1] }
}

// MARK: - Tests

final class CoreOptionsScopedResetTests: XCTestCase {

    private let testMD5   = "aabbccddeeff00112233445566778899"
    private let otherMD5  = "ffffffffffffffffffffffffffffffff"

    override func setUp() {
        super.setUp()
        // Clean up any leftovers from previous runs
        removeAllTestKeys()
    }

    override func tearDown() {
        removeAllTestKeys()
        super.tearDown()
    }

    // MARK: hasPerGameOverride

    func testHasPerGameOverride_returnsFalseWhenNoOverrideSet() {
        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
    }

    func testHasPerGameOverride_returnsTrueAfterValueSet() {
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: testMD5)
        XCTAssertTrue(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
    }

    func testHasPerGameOverride_doesNotSeeGlobalKey() {
        // Setting without MD5 must not be visible as a per-game override
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: nil)
        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
    }

    // MARK: resetOption(_:forMD5:)

    func testResetOption_removesPerGameOverride() {
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: testMD5)
        XCTAssertTrue(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))

        MockCore.resetOption(MockCore.fullscreenOption, forMD5: testMD5)
        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
    }

    func testResetOption_doesNotRemoveGlobalKey() {
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: nil)
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: testMD5)

        MockCore.resetOption(MockCore.fullscreenOption, forMD5: testMD5)

        // Global key must survive
        let className = "\(String(describing: MockCore.self))"
        let globalKey = "\(className).\(MockCore.fullscreenOption.key)"
        XCTAssertNotNil(UserDefaults.standard.object(forKey: globalKey),
                        "Global key should not be removed by resetOption(forMD5:)")
    }

    func testResetOption_doesNotAffectOtherGame() {
        MockCore.setValue(99, forOption: MockCore.volumeOption, andMD5: testMD5)
        MockCore.setValue(10, forOption: MockCore.volumeOption, andMD5: otherMD5)

        MockCore.resetOption(MockCore.volumeOption, forMD5: testMD5)

        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.volumeOption, md5: testMD5))
        XCTAssertTrue(MockCore.hasPerGameOverride(for: MockCore.volumeOption, md5: otherMD5),
                      "Other game's override should be unaffected")
    }

    func testResetOption_isIdempotentWhenNoOverrideExists() {
        // Should not crash when key is already absent
        XCTAssertNoThrow(MockCore.resetOption(MockCore.fullscreenOption, forMD5: testMD5))
        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
    }

    // MARK: resetAllOptions(forMD5:)

    func testResetAllOptions_removesAllOverridesForGame() {
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: testMD5)
        MockCore.setValue(75,    forOption: MockCore.volumeOption,     andMD5: testMD5)

        XCTAssertTrue(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
        XCTAssertTrue(MockCore.hasPerGameOverride(for: MockCore.volumeOption,     md5: testMD5))

        MockCore.resetAllOptions(forMD5: testMD5)

        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.volumeOption,     md5: testMD5))
    }

    func testResetAllOptions_doesNotAffectOtherGame() {
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: testMD5)
        MockCore.setValue(10,    forOption: MockCore.volumeOption,     andMD5: otherMD5)

        MockCore.resetAllOptions(forMD5: testMD5)

        XCTAssertFalse(MockCore.hasPerGameOverride(for: MockCore.fullscreenOption, md5: testMD5))
        XCTAssertTrue(MockCore.hasPerGameOverride(for: MockCore.volumeOption, md5: otherMD5),
                      "Other game's overrides should be unaffected")
    }

    func testResetAllOptions_doesNotRemoveGlobalKeys() {
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: nil)
        MockCore.setValue(false, forOption: MockCore.fullscreenOption, andMD5: testMD5)

        MockCore.resetAllOptions(forMD5: testMD5)

        let className = "\(String(describing: MockCore.self))"
        let globalKey = "\(className).\(MockCore.fullscreenOption.key)"
        XCTAssertNotNil(UserDefaults.standard.object(forKey: globalKey),
                        "Global key should not be removed by resetAllOptions(forMD5:)")
    }

    func testResetAllOptions_isIdempotentWhenNoOverridesExist() {
        XCTAssertNoThrow(MockCore.resetAllOptions(forMD5: testMD5))
    }

    // MARK: perGameKey / perGameKeyPrefix (structural checks)

    func testPerGameKey_hasExpectedFormat() {
        let key = MockCore.perGameKey(for: MockCore.fullscreenOption, md5: testMD5)
        let expected = "MockCore.\(testMD5).video.fullscreen"
        XCTAssertEqual(key, expected)
    }

    func testPerGameKeyPrefix_hasExpectedFormat() {
        let prefix = MockCore.perGameKeyPrefix(md5: testMD5)
        let expected = "MockCore.\(testMD5)."
        XCTAssertEqual(prefix, expected)
    }

    // MARK: - Private helpers

    private func removeAllTestKeys() {
        let defaults = UserDefaults.standard
        let className = "\(String(describing: MockCore.self))"
        let prefixes = [
            "\(className).\(testMD5).",
            "\(className).\(otherMD5).",
            "\(className)."
        ]
        defaults.dictionaryRepresentation().keys.forEach { key in
            if prefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

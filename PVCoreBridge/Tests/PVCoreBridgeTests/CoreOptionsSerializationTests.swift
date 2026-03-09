//
//  CoreOptionsSerializationTests.swift
//  PVCoreBridgeTests
//
//  Tests for per-game MD5 key precedence in CoreOptions+Serialization.
//

@testable import PVCoreBridge
import XCTest

// MARK: - Test fixture

/// A minimal CoreOptional conformer used across all tests.
private struct MockCore: CoreOptional {
    static var options: [CoreOption] {
        [
            .bool(.init(title: "TestBool", description: nil), defaultValue: false),
            .enumeration(.init(title: "TestEnum", description: nil),
                         values: [
                            .init(title: "A", description: "A", value: 0),
                            .init(title: "B", description: "B", value: 1),
                         ],
                         defaultValue: 0),
        ]
    }

    // Tests control this to simulate loading different games.
    static var currentGameMD5: String? = nil
}

private let boolOption = MockCore.options[0]
private let enumOption = MockCore.options[1]

// MARK: - Tests

final class CoreOptionsSerializationTests: XCTestCase {

    // Key helpers
    private let className = "MockCore"

    private func globalKey(for option: CoreOption) -> String {
        "\(className).\(option.key)"
    }

    private func perGameKey(for option: CoreOption, md5: String) -> String {
        "\(className).\(md5).\(option.key)"
    }

    override func setUp() {
        super.setUp()
        // Reset MD5 and clear UserDefaults before each test.
        MockCore.currentGameMD5 = nil
        [globalKey(for: boolOption),
         globalKey(for: enumOption),
         perGameKey(for: boolOption, md5: "abc123"),
         perGameKey(for: enumOption, md5: "abc123"),
         perGameKey(for: boolOption, md5: "def456"),
         perGameKey(for: enumOption, md5: "def456"),
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: - Bool option tests

    func test_valueForOption_bool_returnsDefault_whenNothingStored() {
        let result: Bool = MockCore.valueForOption(boolOption)
        XCTAssertFalse(result, "Should return the option's defaultValue (false) when nothing is stored")
    }

    func test_valueForOption_bool_returnsGlobalValue_whenNoMD5() {
        UserDefaults.standard.set(true, forKey: globalKey(for: boolOption))
        let result: Bool = MockCore.valueForOption(boolOption)
        XCTAssertTrue(result)
    }

    func test_valueForOption_bool_perGameKeyTakesPrecedence() {
        UserDefaults.standard.set(false, forKey: globalKey(for: boolOption))
        UserDefaults.standard.set(true, forKey: perGameKey(for: boolOption, md5: "abc123"))

        MockCore.currentGameMD5 = "abc123"
        let result: Bool = MockCore.valueForOption(boolOption)
        XCTAssertTrue(result, "Per-game key should take precedence over global key")
    }

    func test_valueForOption_bool_fallsBackToGlobal_whenNoPerGameKey() {
        UserDefaults.standard.set(true, forKey: globalKey(for: boolOption))
        // No per-game key stored.

        MockCore.currentGameMD5 = "abc123"
        let result: Bool = MockCore.valueForOption(boolOption)
        XCTAssertTrue(result, "Should fall back to global key when per-game key is absent")
    }

    func test_valueForOption_bool_explicitMD5Overrides_currentGameMD5() {
        UserDefaults.standard.set(false, forKey: globalKey(for: boolOption))
        UserDefaults.standard.set(true, forKey: perGameKey(for: boolOption, md5: "def456"))
        // currentGameMD5 points to a different game with no per-game override.
        MockCore.currentGameMD5 = "abc123"

        let result: Bool = MockCore.valueForOption(boolOption, andMD5: "def456")
        XCTAssertTrue(result, "Explicit andMD5: argument should be used instead of currentGameMD5")
    }

    func test_valueForOption_bool_nilMD5_usesCurrentGameMD5() {
        UserDefaults.standard.set(true, forKey: perGameKey(for: boolOption, md5: "abc123"))
        MockCore.currentGameMD5 = "abc123"

        // Passing nil explicitly should fall through to currentGameMD5.
        let result: Bool = MockCore.valueForOption(boolOption, andMD5: nil)
        XCTAssertTrue(result)
    }

    // MARK: - Enum option tests

    func test_valueForOption_enum_returnsDefault_whenNothingStored() {
        let result: Int = MockCore.valueForOption(enumOption)
        XCTAssertEqual(result, 0)
    }

    func test_valueForOption_enum_perGameKeyTakesPrecedence() {
        UserDefaults.standard.set(0, forKey: globalKey(for: enumOption))
        UserDefaults.standard.set(1, forKey: perGameKey(for: enumOption, md5: "abc123"))

        MockCore.currentGameMD5 = "abc123"
        let result: Int = MockCore.valueForOption(enumOption)
        XCTAssertEqual(result, 1, "Per-game key should take precedence")
    }

    func test_valueForOption_enum_fallsBackToGlobal_whenNoPerGameKey() {
        UserDefaults.standard.set(1, forKey: globalKey(for: enumOption))
        MockCore.currentGameMD5 = "abc123"

        let result: Int = MockCore.valueForOption(enumOption)
        XCTAssertEqual(result, 1, "Should fall back to global key when per-game key is absent")
    }

    // MARK: - CoreOptionValue overload

    func test_valueForOption_coreOptionValue_perGameKeyTakesPrecedence() {
        UserDefaults.standard.set(false, forKey: globalKey(for: boolOption))
        UserDefaults.standard.set(true, forKey: perGameKey(for: boolOption, md5: "abc123"))

        MockCore.currentGameMD5 = "abc123"
        let result = MockCore.valueForOption(boolOption) as CoreOptionValue
        XCTAssertTrue(result.asBool)
    }
}

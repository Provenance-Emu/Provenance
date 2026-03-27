//
//  LightBarColorTests.swift
//  PVCoreBridgeTests
//
//  Unit tests for ControllerLightBarManager.LightBarColor.
//

import XCTest

#if canImport(GameController)
@testable import PVCoreBridge

@available(iOS 14.0, tvOS 14.0, *)
final class LightBarColorTests: XCTestCase {

    // MARK: - Hex Parsing

    func testHexParsingWithHash() {
        let color = ControllerLightBarManager.LightBarColor(hex: "#FF8000")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.red,   Float(0xFF) / 255.0, accuracy: 0.001)
        XCTAssertEqual(color!.green, Float(0x80) / 255.0, accuracy: 0.001)
        XCTAssertEqual(color!.blue,  Float(0x00) / 255.0, accuracy: 0.001)
    }

    func testHexParsingWithoutHash() {
        let color = ControllerLightBarManager.LightBarColor(hex: "0066FF")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.red,   0.0,                  accuracy: 0.001)
        XCTAssertEqual(color!.green, Float(0x66) / 255.0,  accuracy: 0.001)
        XCTAssertEqual(color!.blue,  1.0,                  accuracy: 0.001)
    }

    func testHexParsingBlack() {
        let color = ControllerLightBarManager.LightBarColor(hex: "#000000")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!, .off)
    }

    func testHexParsingWhite() {
        let color = ControllerLightBarManager.LightBarColor(hex: "#FFFFFF")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!, .default)
    }

    func testHexParsingInvalidTooShort() {
        XCTAssertNil(ControllerLightBarManager.LightBarColor(hex: "#FFF"))
    }

    func testHexParsingInvalidChars() {
        XCTAssertNil(ControllerLightBarManager.LightBarColor(hex: "#GGGGGG"))
    }

    // MARK: - Hex String Round-Trip

    func testHexStringRoundTrip() {
        let original = "#3A7BCC"
        let color = ControllerLightBarManager.LightBarColor(hex: original)!
        XCTAssertEqual(color.hexString.uppercased(), original.uppercased())
    }

    func testHexStringForBlack() {
        XCTAssertEqual(ControllerLightBarManager.LightBarColor.off.hexString, "#000000")
    }

    func testHexStringForWhite() {
        XCTAssertEqual(ControllerLightBarManager.LightBarColor.default.hexString, "#FFFFFF")
    }

    // MARK: - Predefined Colors

    func testPlayStationBlueValues() {
        let color = ControllerLightBarManager.LightBarColor.playstationBlue
        XCTAssertEqual(color.red,   0.0,  accuracy: 0.001)
        XCTAssertEqual(color.green, 0.4,  accuracy: 0.001)
        XCTAssertEqual(color.blue,  1.0,  accuracy: 0.001)
    }

    func testAtariGoldValues() {
        let color = ControllerLightBarManager.LightBarColor.atariGold
        XCTAssertEqual(color.red,   1.0,  accuracy: 0.001)
        XCTAssertEqual(color.green, 0.75, accuracy: 0.001)
        XCTAssertEqual(color.blue,  0.0,  accuracy: 0.001)
    }

    // MARK: - Equatable

    func testEqualityForSameValues() {
        let a = ControllerLightBarManager.LightBarColor(red: 0.5, green: 0.5, blue: 0.5)
        let b = ControllerLightBarManager.LightBarColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(a, b)
    }

    func testInequalityForDifferentValues() {
        let a = ControllerLightBarManager.LightBarColor(red: 0.1, green: 0.2, blue: 0.3)
        let b = ControllerLightBarManager.LightBarColor(red: 0.3, green: 0.2, blue: 0.1)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Edge Cases

    func testHexParsingLowercase() {
        let color = ControllerLightBarManager.LightBarColor(hex: "#ff0000")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(color!.green, 0.0, accuracy: 0.001)
        XCTAssertEqual(color!.blue, 0.0, accuracy: 0.001)
    }

    func testHexParsingMixedCase() {
        let a = ControllerLightBarManager.LightBarColor(hex: "#aAbBcC")
        let b = ControllerLightBarManager.LightBarColor(hex: "#AABBCC")
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertEqual(a, b)
    }
}

#endif // canImport(GameController)

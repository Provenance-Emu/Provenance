//
//  LibretroDeviceTypeTests.swift
//  PVCoreBridgeTests
//
//  Created by Claude (Agent) on 2026-03-17.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Validates that LibretroDeviceType.localizedName and symbolName don't
//  accidentally regress (e.g. a typo in an SF Symbol name).
//

@testable import PVCoreBridge
import XCTest

final class LibretroDeviceTypeTests: XCTestCase {

    // MARK: - localizedName

    func testLocalizedNamesAreNonEmpty() {
        let allCases: [LibretroDeviceType] = [.none, .joypad, .mouse, .keyboard, .lightgun, .analog, .pointer]
        for type in allCases {
            XCTAssertFalse(type.localizedName.isEmpty, "\(type) has an empty localizedName")
        }
    }

    func testExpectedLocalizedNames() {
        XCTAssertEqual(LibretroDeviceType.none.localizedName, "None")
        XCTAssertEqual(LibretroDeviceType.joypad.localizedName, "Gamepad")
        XCTAssertEqual(LibretroDeviceType.mouse.localizedName, "Mouse")
        XCTAssertEqual(LibretroDeviceType.keyboard.localizedName, "Keyboard")
        XCTAssertEqual(LibretroDeviceType.lightgun.localizedName, "Light Gun")
        XCTAssertEqual(LibretroDeviceType.analog.localizedName, "Analog")
        XCTAssertEqual(LibretroDeviceType.pointer.localizedName, "Pointer")
    }

    // MARK: - symbolName

    func testSymbolNamesAreNonEmpty() {
        let allCases: [LibretroDeviceType] = [.none, .joypad, .mouse, .keyboard, .lightgun, .analog, .pointer]
        for type in allCases {
            XCTAssertFalse(type.symbolName.isEmpty, "\(type) has an empty symbolName")
        }
    }

    func testExpectedSymbolNames() {
        XCTAssertEqual(LibretroDeviceType.none.symbolName,     "nosign")
        XCTAssertEqual(LibretroDeviceType.joypad.symbolName,   "gamecontroller")
        XCTAssertEqual(LibretroDeviceType.mouse.symbolName,    "computermouse")
        XCTAssertEqual(LibretroDeviceType.keyboard.symbolName, "keyboard")
        XCTAssertEqual(LibretroDeviceType.lightgun.symbolName, "scope")
        XCTAssertEqual(LibretroDeviceType.analog.symbolName,   "gamecontroller.fill")
        XCTAssertEqual(LibretroDeviceType.pointer.symbolName,  "hand.point.up")
    }

    // MARK: - deviceMask

    func testDeviceMaskValue() {
        XCTAssertEqual(LibretroDeviceType.deviceMask, 0xFF,
                       "deviceMask must equal RETRO_DEVICE_MASK (0xFF)")
    }

    func testDeviceMaskStripsSubclassBits() {
        // A subclass ID: RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 1) = (1 | (1 << 8)) = 257
        let subclassId: UInt = 257
        let baseType = subclassId & LibretroDeviceType.deviceMask
        XCTAssertEqual(LibretroDeviceType(rawValue: baseType), .joypad,
                       "Masking a subclass ID should yield the base device type")
    }

    // MARK: - rawValue round-trip

    func testRawValueRoundTrip() {
        let allCases: [(LibretroDeviceType, UInt)] = [
            (.none, 0), (.joypad, 1), (.mouse, 2),
            (.keyboard, 3), (.lightgun, 4), (.analog, 5), (.pointer, 6)
        ]
        for (type, raw) in allCases {
            XCTAssertEqual(type.rawValue, raw, "\(type) has unexpected rawValue")
            XCTAssertEqual(LibretroDeviceType(rawValue: raw), type, "rawValue \(raw) should map back to \(type)")
        }
    }
}

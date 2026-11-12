//
//  ControllerPointerPolicyTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import PVSystems
import XCTest

final class ControllerPointerPolicyTests: XCTestCase {

    private func role(
        _ system: SystemIdentifier?, mouse: Bool = false, gun: Bool = false, pointer: Bool = false,
        pad: Bool = true, mode: ControllerPointerMode = .automatic
    ) -> ControllerPointerRole {
        let context = ControllerPointerContext(
            system: system, gameSupportsMouse: mouse, gameSupportsLightGun: gun,
            coreSupportsPointer: pointer, padHasPointerInput: pad)
        return ControllerPointerPolicy.role(for: context, mode: mode)
    }

    // MARK: - Automatic

    func testPlainGameIsNone() {
        XCTAssertEqual(role(.SNES), .none)
        XCTAssertEqual(role(nil), .none)
    }

    func testMouseGameIsMouse() {
        XCTAssertEqual(role(.SNES, mouse: true), .mouse)
    }

    func testGunGameIsLightGun() {
        XCTAssertEqual(role(.NES, gun: true), .lightGun)
    }

    func testGunBeatsMouse() {
        XCTAssertEqual(role(.SNES, mouse: true, gun: true), .lightGun)
    }

    func testWiiWithPointerCoreIsWiiPointer() {
        XCTAssertEqual(role(.Wii, pointer: true), .wiiPointer)
    }

    func testWiiWithoutPointerCoreIsNone() {
        XCTAssertEqual(role(.Wii), .none)
    }

    func testPointerCoreOnAnotherSystemIsNone() {
        XCTAssertEqual(role(.GameCube, pointer: true), .none)
    }

    func testNoPointerPadIsAlwaysNone() {
        XCTAssertEqual(role(.SNES, mouse: true, pad: false), .none)
        XCTAssertEqual(role(.Wii, pointer: true, pad: false, mode: .wiiPointer), .none)
    }

    func testDSIsAlwaysNone() {
        XCTAssertEqual(role(.DS, mouse: true), .none)
        XCTAssertEqual(role(.DS, mouse: true, mode: .mouse), .none)
    }

    // MARK: - Modes

    func testOffIsNone() {
        XCTAssertEqual(role(.SNES, mouse: true, gun: true, mode: .off), .none)
    }

    func testForcedModeNeedsSupport() {
        XCTAssertEqual(role(.SNES, mouse: true, mode: .mouse), .mouse)
        XCTAssertEqual(role(.SNES, mode: .mouse), .none)
        XCTAssertEqual(role(.NES, mode: .lightGun), .none)
        XCTAssertEqual(role(.SNES, pointer: true, mode: .wiiPointer), .none)
    }

    func testForcedModeOverridesAutomaticOrder() {
        XCTAssertEqual(role(.SNES, mouse: true, gun: true, mode: .mouse), .mouse)
    }

    // MARK: - Bindings

    func testDefaultsPerRole() {
        let mouse = PointerClickBindings.defaults(for: .mouse)
        XCTAssertEqual(mouse[.left], .leftButton)
        XCTAssertEqual(mouse[.right], .leftButton)
        XCTAssertEqual(mouse[.twoFinger], .rightButton)

        let gun = PointerClickBindings.defaults(for: .lightGun)
        XCTAssertEqual(gun[.left], .trigger)
        XCTAssertEqual(gun[.right], .reload)
        XCTAssertEqual(gun[.twoFinger], .pauseMenu)

        let wii = PointerClickBindings.defaults(for: .wiiPointer)
        for zone in TouchpadClickZone.allCases { XCTAssertEqual(wii[zone], .wiiA) }

        let none = PointerClickBindings.defaults(for: .none)
        for zone in TouchpadClickZone.allCases { XCTAssertEqual(none[zone], PointerAction.none) }
    }

    func testBindingsSubscriptWrites() {
        var bindings = PointerClickBindings.defaults(for: .lightGun)
        bindings[.twoFinger] = .auxA
        XCTAssertEqual(bindings.twoFinger, .auxA)
        XCTAssertEqual(bindings[.left], .trigger)
    }

    func testBindingsCodableRoundTrip() throws {
        var bindings = PointerClickBindings.defaults(for: .lightGun)
        bindings[.right] = .gunStart
        let data = try JSONEncoder().encode(bindings)
        XCTAssertEqual(try JSONDecoder().decode(PointerClickBindings.self, from: data), bindings)
    }
}

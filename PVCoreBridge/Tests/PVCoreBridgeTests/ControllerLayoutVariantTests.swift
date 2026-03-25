//
//  ControllerLayoutVariantTests.swift
//  PVCoreBridgeTests
//

import XCTest
@testable import PVCoreBridge
import PVPrimitives

final class ControllerLayoutVariantTests: XCTestCase {

    // MARK: - Variant Identity

    func testVariantIDsAreUnique() {
        let allVariants: [ControllerLayoutVariant] = [
            .genesis3Button, .genesis6Button,
            .wiiWiimote, .wiiWiimoteNunchuck, .wiiClassicController, .wiiClassicControllerPro,
            .atari5200Joystick, .atari5200JoystickOnly,
            .nesStandard, .nesZapper,
        ]
        let ids = allVariants.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "All built-in variant IDs must be unique")
    }

    func testVariantDisplayNamesAreNonEmpty() {
        let allVariants: [ControllerLayoutVariant] = [
            .genesis3Button, .genesis6Button,
            .wiiWiimote, .wiiWiimoteNunchuck, .wiiClassicController, .wiiClassicControllerPro,
            .atari5200Joystick, .atari5200JoystickOnly,
            .nesStandard, .nesZapper,
        ]
        for variant in allVariants {
            XCTAssertFalse(variant.displayName.isEmpty, "\(variant.id) must have a non-empty displayName")
        }
    }

    // MARK: - SystemIdentifier Mapping

    func testGenesisHasTwoVariants() {
        let variants = SystemIdentifier.Genesis.availableControllerLayoutVariants
        XCTAssertEqual(variants?.count, 2)
        XCTAssertEqual(variants?[0].id, "genesis-3btn")
        XCTAssertEqual(variants?[1].id, "genesis-6btn")
    }

    func testWiiHasFourVariants() {
        let variants = SystemIdentifier.Wii.availableControllerLayoutVariants
        XCTAssertEqual(variants?.count, 4)
        XCTAssertEqual(variants?[0].id, "wii-wiimote")
        XCTAssertEqual(variants?[1].id, "wii-wiimote-nunchuck")
        XCTAssertEqual(variants?[2].id, "wii-classic")
        XCTAssertEqual(variants?[3].id, "wii-classic-pro")
    }

    func testAtari5200HasTwoVariants() {
        let variants = SystemIdentifier.Atari5200.availableControllerLayoutVariants
        XCTAssertEqual(variants?.count, 2)
        XCTAssertEqual(variants?[0].id, "5200-joystick")
        XCTAssertEqual(variants?[1].id, "5200-joystick-only")
    }

    func testNESHasTwoVariants() {
        let variants = SystemIdentifier.NES.availableControllerLayoutVariants
        XCTAssertEqual(variants?.count, 2)
        XCTAssertEqual(variants?[0].id, "nes-standard")
        XCTAssertEqual(variants?[1].id, "nes-zapper")
    }

    func testSystemsWithoutVariantsReturnNil() {
        // Systems that have a single fixed layout should return nil
        XCTAssertNil(SystemIdentifier.SNES.availableControllerLayoutVariants)
        XCTAssertNil(SystemIdentifier.GBA.availableControllerLayoutVariants)
        XCTAssertNil(SystemIdentifier.PSX.availableControllerLayoutVariants)
    }

    // MARK: - Default Variant

    func testDefaultVariantIsFirstVariant() {
        XCTAssertEqual(SystemIdentifier.Genesis.defaultControllerLayoutVariant?.id, "genesis-3btn")
        XCTAssertEqual(SystemIdentifier.Wii.defaultControllerLayoutVariant?.id, "wii-wiimote")
        XCTAssertEqual(SystemIdentifier.Atari5200.defaultControllerLayoutVariant?.id, "5200-joystick")
        XCTAssertEqual(SystemIdentifier.NES.defaultControllerLayoutVariant?.id, "nes-standard")
    }

    func testDefaultVariantIsNilForSystemsWithoutVariants() {
        XCTAssertNil(SystemIdentifier.SNES.defaultControllerLayoutVariant)
    }

    // MARK: - Equatable & Hashable

    func testVariantEquality() {
        let v1 = ControllerLayoutVariant(id: "test", displayName: "Test")
        let v2 = ControllerLayoutVariant(id: "test", displayName: "Other Name")
        XCTAssertEqual(v1, v2, "Variants with the same id should be equal")
    }

    func testVariantInequality() {
        let v1 = ControllerLayoutVariant(id: "a", displayName: "A")
        let v2 = ControllerLayoutVariant(id: "b", displayName: "B")
        XCTAssertNotEqual(v1, v2)
    }

    func testVariantIsHashable() {
        let variants: Set<ControllerLayoutVariant> = [.genesis3Button, .genesis6Button, .genesis3Button]
        XCTAssertEqual(variants.count, 2, "Duplicate variants should collapse in a Set")
    }
}

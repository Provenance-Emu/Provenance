import XCTest
@testable import PVSupport

final class PVPhysicalProfileMappingTests: XCTestCase {

    func testStandardSystemNamesResolve() {
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button A"), .buttonA)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Direction Pad"), .dpad)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Left Thumbstick"), .leftThumbstick)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button Options"), .options)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Right Trigger"), .rightTrigger)
    }

    func testN64LabelsFollowRetroArchSemantics() {
        // A → RetroPad B (extended A); B → RetroPad Y (extended X); Z → L2; ZR → Select; Start → Menu.
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "A"), .buttonA)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "B"), .buttonX)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Z"), .leftTrigger)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "ZR"), .options)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Start"), .menu)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Home"), .home)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "C-Up"), .rightStickUp)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "C Down"), .rightStickDown)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "c_left"), .rightStickLeft)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button C Right"), .rightStickRight)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "L"), .leftShoulder)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "R"), .rightShoulder)
    }

    func testN64IndexedButtonsMatchAutoconfig() {
        // RetroArch N64_Nintendo_Switch_Online.cfg: b=1(A) a/y=0(B) start=9 select=10(ZR) l=4 r=5 l2=6(Z)
        // r_x+=8(C Right) r_x-=3(C Left) r_y+=7(C Down) r_y-=2(C Up) menu=12(Home)
        let expected: [Int: PVSynthesizedInput] = [
            0: .buttonX, 1: .buttonA, 2: .rightStickUp, 3: .rightStickLeft, 4: .leftShoulder, 5: .rightShoulder,
            6: .leftTrigger, 7: .rightStickDown, 8: .rightStickRight, 9: .menu, 10: .options, 12: .home,
        ]
        for (index, input) in expected {
            XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button \(index)", isN64Pad: true), input, "Button \(index)")
        }
        XCTAssertNil(PVPhysicalProfileMapping.input(forElementNamed: "Button 11", isN64Pad: true))
        XCTAssertNil(PVPhysicalProfileMapping.input(forElementNamed: "Button 9", isN64Pad: false), "indexed names need the N64 hint")
    }

    func testN64PadDetection() {
        XCTAssertTrue(PVPhysicalProfileMapping.isN64Pad(vendorName: "N64 Controller", productCategory: "HID"))
        XCTAssertFalse(PVPhysicalProfileMapping.isN64Pad(vendorName: "DualSense Wireless Controller", productCategory: "DualSense"))
        XCTAssertFalse(PVPhysicalProfileMapping.isN64Pad(vendorName: nil, productCategory: nil))
    }

    func testStandardNamesWinOverAliasesForTheSameInput() {
        let bindings = PVPhysicalProfileMapping.bindings(forElementNames: ["Start", "Button Menu", "A", "Button A", "Direction Pad"])
        XCTAssertEqual(bindings["Button Menu"], .menu)
        XCTAssertNil(bindings["Start"], "second name for an already-bound input is dropped")
        XCTAssertEqual(bindings["Button A"], .buttonA)
        XCTAssertNil(bindings["A"])
    }

    func testUsabilityNeedsDirectionAndFaceButton() {
        XCTAssertTrue(PVPhysicalProfileMapping.isUsable(bindings: ["Direction Pad": .dpad, "Button A": .buttonA]))
        XCTAssertTrue(PVPhysicalProfileMapping.isUsable(bindings: ["Left Thumbstick": .leftThumbstick, "B": .buttonX]))
        XCTAssertFalse(PVPhysicalProfileMapping.isUsable(bindings: ["Button A": .buttonA, "Button Menu": .menu]))
        XCTAssertFalse(PVPhysicalProfileMapping.isUsable(bindings: ["Direction Pad": .dpad]))
        XCTAssertFalse(PVPhysicalProfileMapping.isUsable(bindings: [:]))
    }

    func testUnknownNamesAreIgnored() {
        XCTAssertNil(PVPhysicalProfileMapping.input(forElementNamed: "Capture"))
        XCTAssertNil(PVPhysicalProfileMapping.input(forElementNamed: "Touchpad"))
    }
}

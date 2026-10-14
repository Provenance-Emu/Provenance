import XCTest
@testable import PVSupport

final class PVPhysicalProfileMappingTests: XCTestCase {

    func testStandardSystemNamesResolve() {
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button A"), .buttonA)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Direction Pad"), .dpad)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Left Thumbstick"), .leftThumbstick)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button Options"), .options)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Right Trigger"), .rightTrigger)
        // Standard names mean the same on every pad family.
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button B", pad: .n64), .buttonB)
    }

    func testPadDetection() {
        XCTAssertEqual(PVPhysicalProfilePad.detect(vendorName: "N64 Controller", productCategory: "HID"), .n64)
        XCTAssertEqual(PVPhysicalProfilePad.detect(vendorName: "SNES Controller", productCategory: "HID"), .snes)
        XCTAssertEqual(PVPhysicalProfilePad.detect(vendorName: "MD/Gen Control Pad", productCategory: "HID"), .megaDrive)
        XCTAssertEqual(PVPhysicalProfilePad.detect(vendorName: "DualSense Wireless Controller", productCategory: "DualSense"), .generic)
        XCTAssertEqual(PVPhysicalProfilePad.detect(vendorName: nil, productCategory: nil), .generic)
    }

    func testN64LabelsFollowRetroArchSemantics() {
        // A → RetroPad B (extended A); B → RetroPad Y (extended X); Z → L2; ZR → Select; Start → Menu.
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "A", pad: .n64), .buttonA)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "B", pad: .n64), .buttonX)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Z", pad: .n64), .leftTrigger)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "ZR", pad: .n64), .options)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Start", pad: .n64), .menu)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Home", pad: .n64), .home)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "C-Up", pad: .n64), .rightStickUp)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "C Down", pad: .n64), .rightStickDown)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "c_left", pad: .n64), .rightStickLeft)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button C Right", pad: .n64), .rightStickRight)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "L", pad: .n64), .leftShoulder)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "R", pad: .n64), .rightShoulder)
    }

    func testSNESLabelsAreTheRetroPadLayout() {
        // SNES_Nintendo_Switch_Online.cfg: B → RetroPad B, A → A, Y → Y, X → X, ZL → L2, ZR → R2.
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "B", pad: .snes), .buttonA)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "A", pad: .snes), .buttonB)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Y", pad: .snes), .buttonX)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "X", pad: .snes), .buttonY)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "ZL", pad: .snes), .leftTrigger)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "ZR", pad: .snes), .rightTrigger)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "SELECT", pad: .snes), .options)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "START", pad: .snes), .menu)
        // The generic family uses the same face layout.
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "B"), .buttonA)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "A"), .buttonB)
    }

    func testMegaDriveLabels() {
        // MD_Gen_Control_Pad_Switch_Online.cfg: B → B, A → Y, Y → X, X → L, Z → R, C → A, Mode → Select.
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "B", pad: .megaDrive), .buttonA)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "A", pad: .megaDrive), .buttonX)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Y", pad: .megaDrive), .buttonY)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "X", pad: .megaDrive), .leftShoulder)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Z", pad: .megaDrive), .rightShoulder)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "C", pad: .megaDrive), .buttonB)
        XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Mode", pad: .megaDrive), .options)
    }

    func testIndexedButtonsMatchAutoconfig() {
        // N64: b=1(A) a/y=0(B) start=9 select=10(ZR) l=4 r=5 l2=6(Z) r_x+=8 r_x-=3 r_y+=7 r_y-=2 menu=12
        let n64: [Int: PVSynthesizedInput] = [
            0: .buttonX, 1: .buttonA, 2: .rightStickUp, 3: .rightStickLeft, 4: .leftShoulder, 5: .rightShoulder,
            6: .leftTrigger, 7: .rightStickDown, 8: .rightStickRight, 9: .menu, 10: .options, 12: .home,
        ]
        for (index, input) in n64 {
            XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button \(index)", pad: .n64), input, "N64 Button \(index)")
        }
        XCTAssertNil(PVPhysicalProfileMapping.input(forElementNamed: "Button 11", pad: .n64))
        // SNES: b=0 a=1 y=2 x=3 l=4 r=5 l2=6(ZL) select=8 start=9 r2=15(ZR)
        let snes: [Int: PVSynthesizedInput] = [
            0: .buttonA, 1: .buttonB, 2: .buttonX, 3: .buttonY, 4: .leftShoulder, 5: .rightShoulder,
            6: .leftTrigger, 8: .options, 9: .menu, 15: .rightTrigger,
        ]
        for (index, input) in snes {
            XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button \(index)", pad: .snes), input, "SNES Button \(index)")
        }
        XCTAssertNil(PVPhysicalProfileMapping.input(forElementNamed: "Button 7", pad: .snes))
        // MD: b=0 y=1(A) x=2(Y) r=4(Z) a=5(C) l=6(X) select=7(Mode) start=9 menu=12(Home)
        let md: [Int: PVSynthesizedInput] = [
            0: .buttonA, 1: .buttonX, 2: .buttonY, 4: .rightShoulder, 5: .buttonB, 6: .leftShoulder, 7: .options, 9: .menu, 12: .home,
        ]
        for (index, input) in md {
            XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button \(index)", pad: .megaDrive), input, "MD Button \(index)")
        }
        XCTAssertNil(PVPhysicalProfileMapping.input(forElementNamed: "Button 9", pad: .generic), "indexed names need a known pad family")
    }

    func testStandardNamesWinOverAliasesForTheSameInput() {
        let bindings = PVPhysicalProfileMapping.bindings(forElementNames: ["Start", "Button Menu", "B", "Button A", "Direction Pad"])
        XCTAssertEqual(bindings["Button Menu"], .menu)
        XCTAssertNil(bindings["Start"], "second name for an already-bound input is dropped")
        XCTAssertEqual(bindings["Button A"], .buttonA)
        XCTAssertNil(bindings["B"])
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

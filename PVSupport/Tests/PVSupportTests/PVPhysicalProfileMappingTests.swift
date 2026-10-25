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

    // MARK: Switch Online SNES pad (VID 0x057E, PID 0x2017)

    /// The nine elements Apple's `_GCNintendoSuperFamicomControllerProfile` describes
    /// (GameController, iOS 26.6 and tvOS 27.2): no Home, no ZL/ZR.
    private let appleSNESElementNames = [
        "Button A", "Button B", "Button X", "Button Y", "Left Shoulder", "Right Shoulder",
        "Button Menu", "Button Options", "Direction Pad",
    ]

    func testSNESPadFromAppleProfileBindsEveryButtonOnce() {
        XCTAssertEqual(PVPhysicalProfilePad.detect(vendorName: "SNES Controller", productCategory: "Switch SNES Controller"), .snes)
        let bindings = PVPhysicalProfileMapping.bindings(forElementNames: appleSNESElementNames, pad: .snes)
        XCTAssertEqual(bindings, [
            "Button A": .buttonA, "Button B": .buttonB, "Button X": .buttonX, "Button Y": .buttonY,
            "Left Shoulder": .leftShoulder, "Right Shoulder": .rightShoulder,
            "Button Menu": .menu, "Button Options": .options, "Direction Pad": .dpad,
        ])
        XCTAssertEqual(Set(bindings.values).count, bindings.count, "no two elements drive the same input")
        XCTAssertTrue(PVPhysicalProfileMapping.isUsable(bindings: bindings))
    }

    func testSNESPadPausesOnSelectPlusStartNeverStartAlone() throws {
        let bindings = PVPhysicalProfileMapping.bindings(forElementNames: appleSNESElementNames, pad: .snes)
        let trigger = try XCTUnwrap(PVPhysicalProfileMapping.pauseTrigger(forBindings: bindings))
        XCTAssertEqual(trigger, .chord([.options, .menu]))
        XCTAssertFalse(trigger.isSatisfied(by: [.menu]), "Start alone is a game button")
        XCTAssertFalse(trigger.isSatisfied(by: [.options]), "Select alone is a game button")
        XCTAssertFalse(trigger.isSatisfied(by: [.menu, .buttonA]))
        XCTAssertTrue(trigger.isSatisfied(by: [.options, .menu]))
        XCTAssertTrue(trigger.isSatisfied(by: [.options, .menu, .dpad]))
        XCTAssertEqual(trigger.inputs, [.options, .menu])
    }

    func testPadsWithHomePauseOnHome() throws {
        let n64 = PVPhysicalProfileMapping.bindings(forElementNames: ["Button A", "Direction Pad", "Button Menu", "Button Options", "Button Home"], pad: .n64)
        let trigger = try XCTUnwrap(PVPhysicalProfileMapping.pauseTrigger(forBindings: n64))
        XCTAssertEqual(trigger, .home)
        XCTAssertTrue(trigger.isSatisfied(by: [.home]))
        XCTAssertFalse(trigger.isSatisfied(by: [.menu, .options]), "with Home available, Select + Start stays a game chord")
        let megaDrive = PVPhysicalProfileMapping.bindings(forElementNames: ["Button 0", "Direction Pad", "Button 9", "Button 12"], pad: .megaDrive)
        XCTAssertEqual(PVPhysicalProfileMapping.pauseTrigger(forBindings: megaDrive), .home)
    }

    func testNoPauseTriggerWithoutHomeOrSelectStart() {
        let bindings = PVPhysicalProfileMapping.bindings(forElementNames: ["Button A", "Direction Pad", "Button Menu"])
        XCTAssertNil(PVPhysicalProfileMapping.pauseTrigger(forBindings: bindings))
        XCTAssertFalse(PVPauseTrigger.chord([]).isSatisfied(by: [.menu]))
    }

    func testOnlySwitchOnlinePadsAreFlagged() {
        XCTAssertTrue(PVPhysicalProfilePad.snes.isSwitchOnline)
        XCTAssertTrue(PVPhysicalProfilePad.n64.isSwitchOnline)
        XCTAssertTrue(PVPhysicalProfilePad.megaDrive.isSwitchOnline)
        XCTAssertFalse(PVPhysicalProfilePad.generic.isSwitchOnline)
    }

    /// The tester's RetroArch autoconfig for this pad agrees with the SNES HID index table.
    func testSNESIndexTableMatchesTesterAutoconfig() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "SNES_Nintendo_Switch_Online", withExtension: "cfg", subdirectory: "Fixtures"))
        let config = try String(contentsOf: url, encoding: .utf8)
        var values: [String: String] = [:]
        for line in config.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            values[parts[0]] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        XCTAssertEqual(values["input_vendor_id"], "1406")
        XCTAssertEqual(values["input_product_id"], "8215")
        // RetroPad button → extended-gamepad input the cores read.
        let retroPad: [String: PVSynthesizedInput] = [
            "b": .buttonA, "a": .buttonB, "y": .buttonX, "x": .buttonY, "l": .leftShoulder, "r": .rightShoulder,
            "l2": .leftTrigger, "r2": .rightTrigger, "select": .options, "start": .menu,
        ]
        for (button, input) in retroPad {
            let index = try XCTUnwrap(values["input_\(button)_btn"].flatMap(Int.init), "input_\(button)_btn")
            XCTAssertEqual(PVPhysicalProfileMapping.input(forElementNamed: "Button \(index)", pad: .snes), input, button)
        }
    }
}

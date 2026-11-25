#if canImport(UIKit) && canImport(GameController)
import GameController
import GamepadKit
@testable import PVSupport
import XCTest

/// Provenance's GamepadKit configuration. The mapping, the wrapper and the pause tracker are
/// tested in the package; these pin the choices that are Provenance's.
final class ProvenancePhysicalProfileTests: XCTestCase {
    private let configuration = PhysicalProfileConfiguration.provenance
    private let appleSNESElementNames = [
        "Button A", "Button B", "Button X", "Button Y", "Direction Pad",
        "Left Shoulder", "Right Shoulder", "Button Menu", "Button Options"
    ]

    func testSwitchOnlineFaceButtonsAreReadAsPrintedLabels() {
        let mapping = configuration.mapping
        // RetroPad: the bottom button (printed B on a Nintendo pad) drives `buttonA`.
        XCTAssertEqual(mapping.input(forElementNamed: "Button A", pad: .snes), .buttonB)
        XCTAssertEqual(mapping.input(forElementNamed: "Button B", pad: .snes), .buttonA)
        XCTAssertEqual(mapping.input(forElementNamed: "Button X", pad: .snes), .buttonY)
        XCTAssertEqual(mapping.input(forElementNamed: "Button Y", pad: .snes), .buttonX)
        XCTAssertEqual(mapping.input(forElementNamed: "Button B", pad: .n64), .buttonX)
        XCTAssertEqual(mapping.input(forElementNamed: "Button A", pad: .generic), .buttonA, "any other pad: positions")
    }

    func testPauseIsHomeElseSelectAndStartAndNeverStartAlone() {
        let snes = configuration.mapping.bindings(forElementNames: appleSNESElementNames, pad: .snes)
        XCTAssertEqual(configuration.pausePolicy.trigger(forBindings: snes, family: .snes), .selectStart)
        let withHome = configuration.mapping.bindings(forElementNames: appleSNESElementNames + ["Button Home"], pad: .n64)
        XCTAssertEqual(configuration.pausePolicy.trigger(forBindings: withHome, family: .n64), .home)
        let startOnly = configuration.mapping.bindings(forElementNames: ["Button A", "Direction Pad", "Button Menu"])
        XCTAssertNil(configuration.pausePolicy.trigger(forBindings: startOnly, family: .generic))
        XCTAssertTrue(configuration.holdsBackPauseInputs)
        XCTAssertEqual(configuration.legacyPausedHandler, .anyTrigger, "PauseMenuTriggerMonitor listens to controllerPausedHandler")
    }

    func testAGenericPadWithAMicroProfileNeedsABOrYButtonAndARemoteIsNeverWrapped() {
        let hid = configuration.mapping.genericBindings(buttonNames: (1 ... 10).map { "Button \($0)" }, directionNames: ["Hat Switch"])
        let remoteLike: [String: GamepadInput] = ["Direction Pad": .dpad, "Button A": .buttonA, "Button X": .buttonX, "Button Menu": .menu]
        func wraps(_ category: String, micro: Bool, _ bindings: [String: GamepadInput], family: PadFamily = .generic) -> Bool {
            configuration.wrapPolicy.shouldWrap(WrapCandidate(family: family, productCategory: category, hasExtendedGamepad: false,
                                                              hasMicroGamepad: micro, isRemote: false, bindings: bindings))
        }
        XCTAssertTrue(wraps("HID", micro: false, hid))
        XCTAssertTrue(wraps("HID", micro: true, hid))
        XCTAssertFalse(wraps("MFi", micro: true, remoteLike))
        XCTAssertFalse(wraps("Remote", micro: true, hid))
        XCTAssertFalse(wraps("Siri Remote", micro: false, hid))
        let snes = configuration.mapping.bindings(forElementNames: appleSNESElementNames, pad: .snes)
        XCTAssertTrue(wraps("Switch SNES Controller", micro: true, snes, family: .snes))
    }

    func testOptionalButtonsAreReportedOnlyWhenThePadHasThem() {
        XCTAssertEqual(configuration.optionsExposure, .whenBound)
        XCTAssertEqual(configuration.homeExposure, .whenBound)
        XCTAssertEqual(configuration.systemGestureDisabledInputs, [.menu, .options])
    }

    func testUnnamedPadsAreNamedSoRemapsDoNotShareOneEntry() {
        XCTAssertEqual(configuration.unnamedPadName?("HID"), "HID Gamepad")
        XCTAssertEqual(configuration.unnamedPadName?("  "), "Gamepad")
    }

    /// The native core bridges find the wrapper by its Objective-C class name and read the
    /// real pad by KVC (`PVIsPhysicalProfileController`, `PVControllerButtonUtils.h`).
    func testTheWrapperKeepsTheObjectiveCSurfaceTheCoreBridgesUse() throws {
        let wrapperClass: AnyClass = try XCTUnwrap(NSClassFromString("GPKPhysicalProfileController"))
        XCTAssertTrue(wrapperClass === PhysicalProfileController.self)
        let pad = GCController()
        let wrapper = PhysicalProfileController(wrapping: pad)
        XCTAssertTrue(wrapper.value(forKey: "base") as? GCController === pad)
        XCTAssertNotNil(wrapper.extendedGamepad)
        XCTAssertNil(wrapper.microGamepad)
        XCTAssertFalse(PhysicalProfileController.isNeeded(for: wrapper), "a wrapper is never wrapped again")
    }
}
#endif

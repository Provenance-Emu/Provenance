//
//  PVRemappedControllerTests.swift
//  PVCoreBridgeTests
//
//  The remap wrapper native cores are handed (PVEmulatorCore.controllerN).
//

import XCTest

#if canImport(GameController) && !os(watchOS)
import GameController
@testable import PVCoreBridge

final class PVRemappedControllerTests: XCTestCase {

    private var suiteName: String!
    private var store: ControllerMappingStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "PVRemappedControllerTests.\(UUID().uuidString)"
        store = ControllerMappingStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)))
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        store = nil
        super.tearDown()
    }

    // MARK: Helpers

    private func makeController() -> GCController {
        GCController.withExtendedGamepad()
    }

    private func vendor(_ controller: GCController) -> String {
        PVRemappedController.mappingVendor(for: controller)
    }

    private func swap(_ a: ButtonIdentifier, _ b: ButtonIdentifier, for controller: GCController) {
        store.setMappings([a: ButtonMapping(source: a, destination: b),
                           b: ButtonMapping(source: b, destination: a)],
                          forVendor: vendor(controller))
    }

    private func coreFacing(_ controller: GCController, coreAppliesRemaps: Bool = false) -> GCController? {
        PVRemappedController.coreFacing(controller, coreAppliesRemaps: coreAppliesRemaps, store: store)
    }

    // MARK: Who gets wrapped

    func testNoRemapsHandsTheRealController() {
        let controller = makeController()
        XCTAssertTrue(coreFacing(controller) === controller)
    }

    func testIdentityMappingsHandTheRealController() {
        let controller = makeController()
        store.setMapping(source: .buttonA, destination: .buttonA, forVendor: vendor(controller))
        XCTAssertFalse(store.hasActiveRemaps(forVendor: vendor(controller)))
        XCTAssertTrue(coreFacing(controller) === controller)
    }

    func testCoreThatRemapsItselfGetsTheRealController() {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        XCTAssertTrue(coreFacing(controller, coreAppliesRemaps: true) === controller)
    }

    func testNilStaysNil() {
        XCTAssertNil(PVRemappedController.coreFacing(nil, coreAppliesRemaps: false, store: store))
    }

    func testAWrapperIsNotWrappedAgain() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let wrapped = try XCTUnwrap(coreFacing(controller))
        XCTAssertTrue(coreFacing(wrapped) === wrapped)
    }

    // MARK: Resolution

    func testSwapABReadsThePhysicalOtherButton() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let base = try XCTUnwrap(controller.extendedGamepad)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)

        XCTAssertTrue(pad.buttonA === base.buttonB)
        XCTAssertTrue(pad.buttonB === base.buttonA)
        XCTAssertTrue(pad.buttonX === base.buttonX)

        base.buttonB.setValue(1)
        XCTAssertTrue(pad.buttonA.isPressed)
        XCTAssertFalse(pad.buttonB.isPressed)
    }

    /// Same rule as the thin wrapper's `remappedPressed`: logical X reads `destination(forSource: X)`.
    func testEveryButtonResolvesLikeTheThinWrapper() throws {
        let controller = makeController()
        let map: [ButtonIdentifier: ButtonIdentifier] = [
            .buttonA: .rightShoulder, .buttonX: .buttonY, .buttonY: .buttonX,
            .leftTrigger: .rightTrigger, .menu: .options, .options: .menu
        ]
        store.setMappings(map.reduce(into: [:]) { $0[$1.key] = ButtonMapping(source: $1.key, destination: $1.value) },
                          forVendor: vendor(controller))
        let base = try XCTUnwrap(controller.extendedGamepad)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)

        let logical: [(ButtonIdentifier, GCControllerButtonInput?)] = [
            (.buttonA, pad.buttonA), (.buttonB, pad.buttonB), (.buttonX, pad.buttonX), (.buttonY, pad.buttonY),
            (.leftShoulder, pad.leftShoulder), (.rightShoulder, pad.rightShoulder),
            (.leftTrigger, pad.leftTrigger), (.rightTrigger, pad.rightTrigger),
            (.menu, pad.buttonMenu), (.options, pad.buttonOptions)
        ]
        for (id, element) in logical {
            let expected = base.pvButton(for: store.destination(forSource: id, vendor: vendor(controller)))
            XCTAssertTrue(element === expected, "\(id) should read \(String(describing: expected))")
        }
    }

    func testRemapEditedWhileWrappedAppliesImmediately() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let base = try XCTUnwrap(controller.extendedGamepad)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)
        XCTAssertTrue(pad.buttonA === base.buttonB)

        store.clearAll(forVendor: vendor(controller))
        XCTAssertTrue(pad.buttonA === base.buttonA)
    }

    func testMissingDestinationIsNeverPressed() throws {
        let controller = makeController()
        store.setMapping(source: .buttonA, destination: .paddleOne, forVendor: vendor(controller))
        let base = try XCTUnwrap(controller.extendedGamepad)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)

        base.buttonA.setValue(1)
        XCTAssertFalse(pad.buttonA.isPressed)
        XCTAssertEqual(pad.buttonA.value, 0)
    }

    func testHomeIsNeverRemapped() throws {
        let controller = makeController()
        store.setMapping(source: .home, destination: .buttonA, forVendor: vendor(controller))
        store.setMapping(source: .buttonB, destination: .buttonA, forVendor: vendor(controller))
        let base = try XCTUnwrap(controller.extendedGamepad)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)
        XCTAssertTrue(pad.buttonHome === base.buttonHome)
    }

    // MARK: D-pad

    func testUnremappedDpadIsTheRealOne() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let base = try XCTUnwrap(controller.extendedGamepad)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)
        XCTAssertTrue(pad.dpad === base.dpad)
    }

    func testDpadDirectionRemapDrivesButtonAndAxis() throws {
        let controller = makeController()
        store.setMapping(source: .dpadUp, destination: .buttonA, forVendor: vendor(controller))
        let base = try XCTUnwrap(controller.extendedGamepad)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)

        XCTAssertFalse(pad.dpad.up.isPressed)
        base.buttonA.setValue(1)
        XCTAssertTrue(pad.dpad.up.isPressed)
        XCTAssertEqual(pad.dpad.yAxis.value, 1, accuracy: 0.001)
        XCTAssertEqual(pad.dpad.xAxis.value, 0, accuracy: 0.001)
        XCTAssertTrue(pad.dpad.down === base.dpad.down)
    }

    // MARK: Snapshots

    func testControllerCaptureIsTheRealSnapshotRemapped() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let wrapped = try XCTUnwrap(coreFacing(controller))
        let base = try XCTUnwrap(controller.extendedGamepad)
        base.buttonB.setValue(1)

        let snapshot = wrapped.capture()
        XCTAssertFalse(snapshot is PVRemappedController)
        XCTAssertTrue(snapshot.isSnapshot)
        XCTAssertEqual(snapshot.extendedGamepad?.buttonA.isPressed, true)
        XCTAssertEqual(snapshot.extendedGamepad?.buttonB.isPressed, false)
        // Writing the remap into the snapshot leaves the live pad alone.
        XCTAssertFalse(base.buttonA.isPressed)
        XCTAssertTrue(base.buttonB.isPressed)
    }

    func testGamepadCaptureIsRemapped() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)
        let base = try XCTUnwrap(controller.extendedGamepad)
        base.buttonB.setValue(1)
        base.leftTrigger.setValue(0.5)

        let snapshot = pad.capture()
        XCTAssertFalse(snapshot is PVRemappedGamepad)
        XCTAssertTrue(snapshot.buttonA.isPressed)
        XCTAssertFalse(snapshot.buttonB.isPressed)
        XCTAssertEqual(snapshot.leftTrigger.value, 0.5, accuracy: 0.001)
        XCTAssertTrue(base.buttonB.isPressed)
    }

    func testGamepadCaptureCarriesDpadRemap() throws {
        let controller = makeController()
        store.setMapping(source: .dpadLeft, destination: .buttonX, forVendor: vendor(controller))
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)
        try XCTUnwrap(controller.extendedGamepad).buttonX.setValue(1)

        let snapshot = pad.capture()
        XCTAssertTrue(snapshot.dpad.left.isPressed)
        XCTAssertEqual(snapshot.dpad.xAxis.value, -1, accuracy: 0.001)
    }

    /// Bridges capture on their emulation thread.
    func testCaptureOffTheMainThread() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let pad = try XCTUnwrap(coreFacing(controller)?.extendedGamepad)
        try XCTUnwrap(controller.extendedGamepad).buttonB.setValue(1)
        nonisolated(unsafe) let unsafePad = pad

        let done = expectation(description: "captured on a background queue")
        DispatchQueue.global(qos: .userInteractive).async {
            for _ in 0..<100 {
                let snapshot = unsafePad.capture()
                XCTAssertTrue(snapshot.buttonA.isPressed)
                XCTAssertFalse(snapshot.buttonB.isPressed)
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
    }

    // MARK: Wrapped pads with their own identity

    /// `PVPhysicalProfileController` (PVSupport) returns itself from `capture()` and is
    /// recognized by bridges through `PVIsPhysicalProfileController`, which reads `base` by KVC.
    func testSelfCapturingControllerStaysReachableThroughBase() throws {
        let profileLike = SelfCapturingController(wrapping: makeController())
        swap(.buttonA, .buttonB, for: profileLike)
        let wrapped = try XCTUnwrap(coreFacing(profileLike) as? PVRemappedController)

        XCTAssertTrue(wrapped.value(forKey: "base") as AnyObject === profileLike)
        // It can't be written to, so the wrapper is its snapshot, still remapped.
        XCTAssertTrue(wrapped.capture() === wrapped)
        XCTAssertTrue(wrapped.extendedGamepad?.buttonA === profileLike.extendedGamepad?.buttonB)
    }

    func testFamilyChecksSeeTheRealPad() {
        let dualSense = GCDualSenseGamepad()
        let pad: GCExtendedGamepad = PVRemappedGamepad(base: dualSense) { $0 == .buttonA ? .buttonB : $0 }

        XCTAssertTrue(pad.isKind(of: GCDualSenseGamepad.self))
        XCTAssertFalse(pad.isKind(of: GCXboxGamepad.self))
        let asDualSense = pad as? GCDualSenseGamepad
        XCTAssertNotNil(asDualSense)
        XCTAssertTrue(asDualSense?.touchpadButton === dualSense.touchpadButton)
        XCTAssertTrue(pad.buttonA === dualSense.buttonB)
    }

    func testControllerPropertiesForwardToTheRealController() throws {
        let controller = makeController()
        swap(.buttonA, .buttonB, for: controller)
        let wrapped = try XCTUnwrap(coreFacing(controller))

        XCTAssertEqual(wrapped.vendorName, controller.vendorName)
        XCTAssertEqual(wrapped.productCategory, controller.productCategory)
        XCTAssertTrue(wrapped.physicalInputProfile === controller.physicalInputProfile)
        wrapped.playerIndex = .index3
        XCTAssertEqual(controller.playerIndex, .index3)
        XCTAssertTrue(wrapped.extendedGamepad?.controller === wrapped)
    }

    // MARK: Store

    func testStorePostsDidChangeForItsVendor() {
        let posted = expectation(forNotification: ControllerMappingStore.didChangeNotification, object: store) { note in
            note.userInfo?[ControllerMappingStore.vendorUserInfoKey] as? String == "Pad"
        }
        store.setMapping(source: .buttonA, destination: .buttonB, forVendor: "Pad")
        wait(for: [posted], timeout: 1)
    }
}

/// Stands in for `PVPhysicalProfileController`: wraps a pad and is its own snapshot.
private final class SelfCapturingController: GCController {
    let inner: GCController

    init(wrapping controller: GCController) {
        inner = controller
        super.init()
    }

    override var extendedGamepad: GCExtendedGamepad? { inner.extendedGamepad }
    override var vendorName: String? { "Switch Online SNES" }
    override func capture() -> GCController { self }
}
#endif

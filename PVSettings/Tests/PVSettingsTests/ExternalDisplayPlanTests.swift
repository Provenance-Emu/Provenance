//
//  ExternalDisplayPlanTests.swift
//  PVSettings
//
//  What each screen shows with an external display connected.
//

import Testing
@testable import PVSettings

@Suite("ExternalDisplayPlan")
struct ExternalDisplayPlanTests {

    private func plan(mode: ExternalDisplayMode = .dedicated,
                      connected: Bool = true,
                      coreCanPresent: Bool = true,
                      controller: Bool = false,
                      skinHasOwnArt: Bool = false,
                      devicePicture: ExternalDisplayDevicePicture = .auto) -> ExternalDisplayPlan {
        ExternalDisplayPlan(.init(mode: mode,
                                  externalDisplayConnected: connected,
                                  coreCanPresentExternally: coreCanPresent,
                                  hardwareControllerConnected: controller,
                                  skinHasOwnArt: skinHasOwnArt,
                                  devicePicture: devicePicture))
    }

    @Test("Touch play on generated controls turns the device into a controller")
    func touchPlayGeneratedControls() {
        let plan = plan()
        #expect(plan.gameOnExternalDisplay)
        #expect(!plan.pictureOnDevice)
    }

    @Test("A skin with its own art keeps the picture on the device")
    func touchPlayRealSkin() {
        let plan = plan(skinHasOwnArt: true)
        #expect(plan.gameOnExternalDisplay)
        #expect(plan.pictureOnDevice)
    }

    @Test("A hardware controller keeps the picture on the device")
    func hardwareController() {
        let plan = plan(controller: true)
        #expect(plan.gameOnExternalDisplay)
        #expect(plan.pictureOnDevice)
    }

    @Test("On and Off override the automatic choice", arguments: [true, false], [true, false])
    func explicitChoiceWins(controller: Bool, skinHasOwnArt: Bool) {
        #expect(plan(controller: controller, skinHasOwnArt: skinHasOwnArt, devicePicture: .on).pictureOnDevice)
        #expect(!plan(controller: controller, skinHasOwnArt: skinHasOwnArt, devicePicture: .off).pictureOnDevice)
    }

    @Test("Mirror mode leaves everything on the device")
    func mirrorMode() {
        let plan = plan(mode: .systemMirror, devicePicture: .off)
        #expect(!plan.gameOnExternalDisplay)
        #expect(plan.pictureOnDevice)
    }

    @Test("No display connected leaves everything on the device")
    func notConnected() {
        let plan = plan(connected: false, devicePicture: .off)
        #expect(!plan.gameOnExternalDisplay)
        #expect(plan.pictureOnDevice)
    }

    @Test("A core that draws into its own view is mirrored, with its picture left on the device")
    func ownSurfaceCore() {
        let plan = plan(coreCanPresent: false, devicePicture: .off)
        #expect(!plan.gameOnExternalDisplay)
        #expect(plan.pictureOnDevice)
    }

    @Test("ExternalDisplayDevicePicture raw values are stable")
    func devicePictureRawValues() {
        #expect(ExternalDisplayDevicePicture.auto.rawValue == "auto")
        #expect(ExternalDisplayDevicePicture.on.rawValue == "on")
        #expect(ExternalDisplayDevicePicture.off.rawValue == "off")
    }
}

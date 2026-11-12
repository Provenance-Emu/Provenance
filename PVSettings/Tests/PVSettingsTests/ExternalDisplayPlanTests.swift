//
//  ExternalDisplayPlanTests.swift
//  PVSettings
//
//  What each screen shows with an external display connected.
//

import Testing
import Defaults
@testable import PVSettings

@Suite("ExternalDisplayPlan")
struct ExternalDisplayPlanTests {

    private func plan(mode: ExternalDisplayMode = .dedicated,
                      connected: Bool = true,
                      coreCanPresent: Bool = true,
                      controller: Bool = false,
                      deviceSkin: ExternalDisplayPlan.DeviceSkin = .generatedControls,
                      devicePicture: ExternalDisplayDevicePicture = .auto,
                      externalSkin: ExternalDisplaySkin = .realSkinsOnly,
                      bezelChosen: Bool = false) -> ExternalDisplayPlan {
        ExternalDisplayPlan(.init(mode: mode,
                                  externalDisplayConnected: connected,
                                  coreCanPresentExternally: coreCanPresent,
                                  hardwareControllerConnected: controller,
                                  deviceSkin: deviceSkin,
                                  devicePicture: devicePicture,
                                  externalSkin: externalSkin,
                                  bezelChosen: bezelChosen))
    }

    @Test("A TV takes the place of the skin around the picture")
    func bezelReplacesSkin() {
        let plan = plan(deviceSkin: .real, externalSkin: .always, bezelChosen: true)
        #expect(plan.bezelOnExternalDisplay)
        #expect(!plan.skinOnExternalDisplay)
    }

    @Test("No TV leaves the skin setting in charge")
    func noBezelKeepsSkin() {
        let plan = plan(deviceSkin: .real, externalSkin: .always)
        #expect(!plan.bezelOnExternalDisplay)
        #expect(plan.skinOnExternalDisplay)
    }

    @Test("A TV needs the game on the external display",
          arguments: [(ExternalDisplayMode.dedicated, false, true), (.dedicated, true, false)])
    func bezelNeedsDedicatedPicture(mode: ExternalDisplayMode, connected: Bool, coreCanPresent: Bool) {
        let plan = plan(mode: mode, connected: connected, coreCanPresent: coreCanPresent, bezelChosen: true)
        #expect(!plan.gameOnExternalDisplay)
        #expect(!plan.bezelOnExternalDisplay)
    }

    @Test("Touch play on generated controls turns the device into a controller")
    func touchPlayGeneratedControls() {
        let plan = plan()
        #expect(plan.gameOnExternalDisplay)
        #expect(!plan.pictureOnDevice)
    }

    @Test("A skin keeps the picture on the device", arguments: [ExternalDisplayPlan.DeviceSkin.builtIn, .real])
    func touchPlaySkin(deviceSkin: ExternalDisplayPlan.DeviceSkin) {
        let plan = plan(deviceSkin: deviceSkin)
        #expect(plan.gameOnExternalDisplay)
        #expect(plan.pictureOnDevice)
    }

    @Test("A hardware controller keeps the picture on the device")
    func hardwareController() {
        let plan = plan(controller: true)
        #expect(plan.gameOnExternalDisplay)
        #expect(plan.pictureOnDevice)
    }

    @Test("On and Off override the automatic choice", arguments: [true, false],
          [ExternalDisplayPlan.DeviceSkin.generatedControls, .real])
    func explicitChoiceWins(controller: Bool, deviceSkin: ExternalDisplayPlan.DeviceSkin) {
        #expect(plan(controller: controller, deviceSkin: deviceSkin, devicePicture: .on).pictureOnDevice)
        #expect(!plan(controller: controller, deviceSkin: deviceSkin, devicePicture: .off).pictureOnDevice)
    }

    @Test("Real Skins Only draws only an installed skin on the display")
    func realSkinsOnly() {
        #expect(plan(deviceSkin: .real).skinOnExternalDisplay)
        #expect(!plan(deviceSkin: .builtIn).skinOnExternalDisplay)
        #expect(!plan(deviceSkin: .generatedControls).skinOnExternalDisplay)
    }

    @Test("Always adds built-in skins, but generated controls have nothing to draw")
    func alwaysSkin() {
        #expect(plan(deviceSkin: .real, externalSkin: .always).skinOnExternalDisplay)
        #expect(plan(deviceSkin: .builtIn, externalSkin: .always).skinOnExternalDisplay)
        #expect(!plan(deviceSkin: .generatedControls, externalSkin: .always).skinOnExternalDisplay)
    }

    @Test("Never keeps the picture alone on the display")
    func neverSkin() {
        #expect(!plan(deviceSkin: .real, externalSkin: .never).skinOnExternalDisplay)
    }

    @Test("A mirrored display draws no skin of its own")
    func mirroredHasNoSkin() {
        #expect(!plan(mode: .systemMirror, deviceSkin: .real, externalSkin: .always).skinOnExternalDisplay)
        #expect(!plan(coreCanPresent: false, deviceSkin: .real, externalSkin: .always).skinOnExternalDisplay)
    }

    @Test("ExternalDisplaySkin defaults to real skins and keeps its raw values")
    func externalSkinSetting() {
        Defaults.reset(.externalDisplaySkin)
        #expect(Defaults[.externalDisplaySkin] == .realSkinsOnly)
        #expect(ExternalDisplaySkin.always.rawValue == "always")
        #expect(ExternalDisplaySkin.realSkinsOnly.rawValue == "realSkinsOnly")
        #expect(ExternalDisplaySkin.never.rawValue == "never")
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

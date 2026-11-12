//
//  ExternalDisplayPlan.swift
//  PVSettings
//
//  What each screen shows while a game runs with an external display connected.
//

import Foundation

/// The outcome of the external display settings for one moment of play.
///
/// Pure: every input is passed in, so the rules are testable without a display.
public struct ExternalDisplayPlan: Equatable, Sendable {

    /// What supplies the controls on the device.
    public enum DeviceSkin: Equatable, Sendable {
        /// The generated touch controls: buttons only, no artwork around the picture.
        case generatedControls
        /// A skin that ships with the app (the case-controller companions).
        case builtIn
        /// A skin the user installed.
        case real
    }

    public struct Inputs: Equatable, Sendable {
        public var mode: ExternalDisplayMode
        /// An external display (cabled or AirPlay) is connected.
        public var externalDisplayConnected: Bool
        /// The running core hands its frames to the app, so they can be drawn on a second screen.
        public var coreCanPresentExternally: Bool
        public var hardwareControllerConnected: Bool
        public var deviceSkin: DeviceSkin
        public var devicePicture: ExternalDisplayDevicePicture
        public var externalSkin: ExternalDisplaySkin
        /// A TV is set to surround the picture on the external display
        /// (`ExternalDisplayBezelRules.bezelID` is not `nil`).
        public var bezelChosen: Bool

        public init(mode: ExternalDisplayMode,
                    externalDisplayConnected: Bool,
                    coreCanPresentExternally: Bool,
                    hardwareControllerConnected: Bool,
                    deviceSkin: DeviceSkin,
                    devicePicture: ExternalDisplayDevicePicture,
                    externalSkin: ExternalDisplaySkin,
                    bezelChosen: Bool = false) {
            self.mode = mode
            self.externalDisplayConnected = externalDisplayConnected
            self.coreCanPresentExternally = coreCanPresentExternally
            self.hardwareControllerConnected = hardwareControllerConnected
            self.deviceSkin = deviceSkin
            self.devicePicture = devicePicture
            self.externalSkin = externalSkin
            self.bezelChosen = bezelChosen
        }
    }

    /// The external display shows the game picture on its own. When `false` the OS mirrors the device.
    public let gameOnExternalDisplay: Bool
    /// The device draws the game picture.
    public let pictureOnDevice: Bool
    /// The external display draws the device's skin around the picture, when the skin has a
    /// layout that suits it (the caller checks that).
    public let skinOnExternalDisplay: Bool
    /// The external display draws a TV around the picture. It takes the place of the skin.
    public let bezelOnExternalDisplay: Bool

    public init(_ inputs: Inputs) {
        gameOnExternalDisplay = inputs.mode == .dedicated
            && inputs.externalDisplayConnected
            && inputs.coreCanPresentExternally
        guard gameOnExternalDisplay else {
            // Mirrored (or no display): the device is the only place the picture is drawn.
            pictureOnDevice = true
            skinOnExternalDisplay = false
            bezelOnExternalDisplay = false
            return
        }
        bezelOnExternalDisplay = inputs.bezelChosen
        switch inputs.externalSkin {
        case _ where inputs.bezelChosen:
            skinOnExternalDisplay = false
        case .always:
            // Generated controls have no artwork to show.
            skinOnExternalDisplay = inputs.deviceSkin != .generatedControls
        case .realSkinsOnly:
            skinOnExternalDisplay = inputs.deviceSkin == .real
        case .never:
            skinOnExternalDisplay = false
        }
        switch inputs.devicePicture {
        case .on:
            pictureOnDevice = true
        case .off:
            pictureOnDevice = false
        case .auto:
            // Touch play on generated controls leaves the device as a controller. A skin with
            // artwork frames the picture, and with a hardware controller the device is a second view.
            pictureOnDevice = inputs.hardwareControllerConnected || inputs.deviceSkin != .generatedControls
        }
    }
}

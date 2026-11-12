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

    public struct Inputs: Equatable, Sendable {
        public var mode: ExternalDisplayMode
        /// An external display (cabled or AirPlay) is connected.
        public var externalDisplayConnected: Bool
        /// The running core hands its frames to the app, so they can be drawn on a second screen.
        public var coreCanPresentExternally: Bool
        public var hardwareControllerConnected: Bool
        /// The skin on the device has artwork of its own, as opposed to generated touch controls.
        public var skinHasOwnArt: Bool
        public var devicePicture: ExternalDisplayDevicePicture

        public init(mode: ExternalDisplayMode,
                    externalDisplayConnected: Bool,
                    coreCanPresentExternally: Bool,
                    hardwareControllerConnected: Bool,
                    skinHasOwnArt: Bool,
                    devicePicture: ExternalDisplayDevicePicture) {
            self.mode = mode
            self.externalDisplayConnected = externalDisplayConnected
            self.coreCanPresentExternally = coreCanPresentExternally
            self.hardwareControllerConnected = hardwareControllerConnected
            self.skinHasOwnArt = skinHasOwnArt
            self.devicePicture = devicePicture
        }
    }

    /// The external display shows the game picture on its own. When `false` the OS mirrors the device.
    public let gameOnExternalDisplay: Bool
    /// The device draws the game picture.
    public let pictureOnDevice: Bool

    public init(_ inputs: Inputs) {
        gameOnExternalDisplay = inputs.mode == .dedicated
            && inputs.externalDisplayConnected
            && inputs.coreCanPresentExternally
        guard gameOnExternalDisplay else {
            // Mirrored (or no display): the device is the only place the picture is drawn.
            pictureOnDevice = true
            return
        }
        switch inputs.devicePicture {
        case .on:
            pictureOnDevice = true
        case .off:
            pictureOnDevice = false
        case .auto:
            // Touch play on generated controls leaves the device as a controller. A skin with
            // artwork frames the picture, and with a hardware controller the device is a second view.
            pictureOnDevice = inputs.hardwareControllerConnected || inputs.skinHasOwnArt
        }
    }
}

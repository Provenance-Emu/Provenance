///
/// ControllerGuideInfo.swift
/// PVUI
///
/// Data model for the hardware controller pairing guide shown in empty-library contexts.
///

import Foundation

// MARK: - ControllerPairingStep

/// A single step in a controller pairing flow.
public struct ControllerPairingStep: Identifiable, Sendable {
    public let id: Int
    public let description: String

    public init(id: Int, description: String) {
        self.id = id
        self.description = description
    }
}

// MARK: - ControllerGuideInfo

/// Metadata for a supported hardware controller.
public struct ControllerGuideInfo: Identifiable, Sendable {
    public let id: String
    /// Display name shown in the guide list.
    public let name: String
    /// SF Symbol name that best represents this controller.
    public let symbolName: String
    /// Short one-line description shown in the card.
    public let tagline: String
    /// Step-by-step Bluetooth pairing instructions.
    public let pairingSteps: [ControllerPairingStep]

    public init(
        id: String,
        name: String,
        symbolName: String,
        tagline: String,
        pairingSteps: [ControllerPairingStep]
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.tagline = tagline
        self.pairingSteps = pairingSteps
    }
}

// MARK: - Built-in controller catalogue

extension ControllerGuideInfo {

    /// All controllers Provenance officially supports, in recommended order.
    public static let all: [ControllerGuideInfo] = [
        .mfiGamepad,
        .ps5DualSense,
        .ps4DualShock,
        .xboxSeriesX,
        .xboxOne,
        .nintendoSwitch,
        .steelSeriesNimbus,
        .razerKishi,
        .backbone,
        .snackboxMicro,
        .keyboard,
        .icade
    ]

    // MARK: Controllers

    public static let mfiGamepad = ControllerGuideInfo(
        id: "mfi",
        name: "MFi Certified Controller",
        symbolName: "gamecontroller.fill",
        tagline: "Any Made-for-iPhone certified gamepad works out of the box.",
        pairingSteps: [
            .init(id: 1, description: "Put the controller in Bluetooth pairing mode (see its manual)."),
            .init(id: 2, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 3, description: "Tap the controller name when it appears."),
            .init(id: 4, description: "Launch Provenance – the controller is detected automatically.")
        ]
    )

    public static let ps5DualSense = ControllerGuideInfo(
        id: "ps5",
        name: "PS5 DualSense",
        symbolName: "playstation.logo",
        tagline: "Full button mapping including touchpad click and haptics.",
        pairingSteps: [
            .init(id: 1, description: "Hold PS + Create buttons until the light bar flashes white."),
            .init(id: 2, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 3, description: "Tap \"DualSense Wireless Controller\" in the device list."),
            .init(id: 4, description: "Open Provenance to start playing.")
        ]
    )

    public static let ps4DualShock = ControllerGuideInfo(
        id: "ps4",
        name: "PS4 DualShock 4",
        symbolName: "playstation.logo",
        tagline: "Widely compatible; works wirelessly over Bluetooth.",
        pairingSteps: [
            .init(id: 1, description: "Hold PS + Share buttons until the light bar flashes."),
            .init(id: 2, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 3, description: "Tap \"DUALSHOCK 4 Wireless Controller\"."),
            .init(id: 4, description: "Open Provenance to start playing.")
        ]
    )

    public static let xboxSeriesX = ControllerGuideInfo(
        id: "xbox-series",
        name: "Xbox Series X|S Controller",
        symbolName: "xbox.logo",
        tagline: "Requires Bluetooth mode (not Xbox wireless).",
        pairingSteps: [
            .init(id: 1, description: "Hold the Xbox button to power on."),
            .init(id: 2, description: "Hold the Pair button (top of controller) until the Xbox logo flashes."),
            .init(id: 3, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 4, description: "Tap the Xbox controller in the device list."),
            .init(id: 5, description: "Open Provenance to start playing.")
        ]
    )

    public static let xboxOne = ControllerGuideInfo(
        id: "xbox-one",
        name: "Xbox One Controller",
        symbolName: "xbox.logo",
        tagline: "Works over Bluetooth (requires 2015 model or later).",
        pairingSteps: [
            .init(id: 1, description: "Hold the Xbox button to power on."),
            .init(id: 2, description: "Hold the Pair button until the Xbox logo flashes."),
            .init(id: 3, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 4, description: "Tap the Xbox controller in the device list."),
            .init(id: 5, description: "Open Provenance to start playing.")
        ]
    )

    public static let nintendoSwitch = ControllerGuideInfo(
        id: "switch",
        name: "Nintendo Switch Pro Controller",
        symbolName: "gamecontroller",
        tagline: "Pair as a standard Bluetooth gamepad.",
        pairingSteps: [
            .init(id: 1, description: "Hold the Sync button on the controller until the lights cycle."),
            .init(id: 2, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 3, description: "Tap \"Pro Controller\" when it appears."),
            .init(id: 4, description: "Open Provenance to start playing.")
        ]
    )

    public static let steelSeriesNimbus = ControllerGuideInfo(
        id: "nimbus",
        name: "SteelSeries Nimbus+",
        symbolName: "gamecontroller.fill",
        tagline: "Premium MFi controller with clickable thumbsticks.",
        pairingSteps: [
            .init(id: 1, description: "Hold the Bluetooth button until the indicator flashes."),
            .init(id: 2, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 3, description: "Tap \"Nimbus+\" in the device list."),
            .init(id: 4, description: "Open Provenance to start playing.")
        ]
    )

    public static let razerKishi = ControllerGuideInfo(
        id: "kishi",
        name: "Razer Kishi",
        symbolName: "iphone",
        tagline: "Plug-in controller for Lightning or USB-C iPhones.",
        pairingSteps: [
            .init(id: 1, description: "Extend the Kishi and slide your iPhone into the mount."),
            .init(id: 2, description: "The controller is detected immediately – no Bluetooth needed."),
            .init(id: 3, description: "Open Provenance to start playing.")
        ]
    )

    public static let backbone = ControllerGuideInfo(
        id: "backbone",
        name: "Backbone One",
        symbolName: "iphone",
        tagline: "Clip-on MFi controller compatible with all iPhone models.",
        pairingSteps: [
            .init(id: 1, description: "Extend the Backbone and attach your iPhone."),
            .init(id: 2, description: "The controller is detected immediately via the Lightning/USB-C port."),
            .init(id: 3, description: "Open Provenance to start playing.")
        ]
    )

    public static let snackboxMicro = ControllerGuideInfo(
        id: "snackbox",
        name: "Snackbox Micro",
        symbolName: "gamecontroller",
        tagline: "Arcade-stick style leverless controller over Bluetooth.",
        pairingSteps: [
            .init(id: 1, description: "Hold the Bluetooth button until the LED flashes."),
            .init(id: 2, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 3, description: "Tap the Snackbox Micro in the device list."),
            .init(id: 4, description: "Open Provenance to start playing.")
        ]
    )

    public static let keyboard = ControllerGuideInfo(
        id: "keyboard",
        name: "Bluetooth / USB Keyboard",
        symbolName: "keyboard.fill",
        tagline: "Use any keyboard for WASD/arrow controls.",
        pairingSteps: [
            .init(id: 1, description: "Put the keyboard in Bluetooth pairing mode."),
            .init(id: 2, description: "On your iPhone open Settings > Bluetooth."),
            .init(id: 3, description: "Tap the keyboard name when it appears."),
            .init(id: 4, description: "In Provenance open Settings > Controllers to view the key map.")
        ]
    )

    public static let icade = ControllerGuideInfo(
        id: "icade",
        name: "iCade / 8Bitdo Zero",
        symbolName: "gamecontroller",
        tagline: "Bluetooth keyboard-emulation controllers supported via iCade mode.",
        pairingSteps: [
            .init(id: 1, description: "Pair the iCade controller via Settings > Bluetooth."),
            .init(id: 2, description: "In Provenance open Settings > Controllers > iCade."),
            .init(id: 3, description: "Follow the on-screen pairing prompts."),
            .init(id: 4, description: "Select your controller type to map buttons correctly.")
        ]
    )
}

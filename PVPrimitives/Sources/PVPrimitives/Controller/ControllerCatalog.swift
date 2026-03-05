//
//  ControllerCatalog.swift
//  PVPrimitives
//
//  Created by Provenance Emu on 2026-03-05.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

// MARK: - ControllerCatalog

/// A static catalog of hardware controllers supported by Provenance.
///
/// Use `ControllerCatalog.all` to get the full list, or the typed accessors
/// for filtered subsets.
///
/// ### Why modern controllers are preferred
/// Modern controllers (DualSense, Xbox Wireless, Switch Pro) expose a full
/// button layout including two analog sticks, two analog triggers (L2/R2),
/// four face buttons, two shoulder buttons, Start/Select equivalents, and
/// clickable thumbsticks (L3/R3). This maps 1:1 with many 5th- and 6th-
/// generation console layouts and enables accurate emulation of games that
/// require analog input. They also benefit from lower Bluetooth latency and
/// richer haptic feedback compared to older MFi or iCade accessories.
///
/// ### Siri Remote limitations
/// The Siri Remote (1st–3rd generation) has only a directional-pad / touch
/// surface and two primary buttons (Menu + Play/Pause on gen 1-2; Back +
/// Click surface on gen 3). Provenance restricts Siri Remote gameplay to
/// systems that require at most 2 buttons (e.g. Atari 2600, Game & Watch).
/// The Menu button is reserved for returning to the tvOS home screen and
/// cannot be remapped by third-party apps.
public enum ControllerCatalog {

    // MARK: Full catalog

    /// All controllers known to Provenance, ordered recommended-first.
    public static let all: [ControllerGuideInfo] = [
        dualSense,
        xboxSeriesX,
        switchPro,
        dualShock4,
        mfiStandard,
        siriRemote,
        iCade,
    ]

    // MARK: - Individual entries

    /// Sony DualSense Wireless Controller (PS5)
    public static let dualSense = ControllerGuideInfo(
        name: "DualSense Wireless Controller",
        controllerType: .dualSense,
        supportedPlatforms: .all,
        pairingInstructions: [
            "Make sure your DualSense is not connected to a PlayStation 5.",
            "Press and hold the PS button and the Create button simultaneously until the light bar blinks rapidly.",
            "On your iPhone/iPad or Apple TV, open Settings > Bluetooth.",
            "Select \"DualSense Wireless Controller\" from the list of available devices.",
            "The light bar will turn solid once paired. Launch Provenance to start playing.",
        ],
        featureNotes: [
            "Full button layout: 4 face buttons, L1/L2/R1/R2 triggers, L3/R3 thumbstick clicks, Options, Create, PS button.",
            "Dual analog sticks with full 360° range – required for 3D games.",
            "Analog L2/R2 triggers for accurate emulation of pressure-sensitive inputs.",
            "Adaptive haptic feedback supported via Apple Game Controller framework.",
            "Touchpad not directly exposed in MFi API but controller is fully functional.",
            "Recommended for PlayStation 1 & 2, Nintendo 64, GameCube, and any 3D system.",
        ],
        isRecommended: true,
        imageAssetName: "controller-dualsense"
    )

    /// Microsoft Xbox Wireless Controller (Series X|S / One)
    public static let xboxSeriesX = ControllerGuideInfo(
        name: "Xbox Wireless Controller",
        controllerType: .xbox,
        supportedPlatforms: .all,
        pairingInstructions: [
            "Turn on the Xbox controller by pressing the Xbox button (glowing X logo).",
            "Press and hold the Pair button (small circular button on top) until the Xbox button blinks rapidly.",
            "On your iPhone/iPad or Apple TV, open Settings > Bluetooth.",
            "Select \"Xbox Wireless Controller\" from the list of available devices.",
            "The Xbox button will stop blinking and stay solid once paired.",
        ],
        featureNotes: [
            "Full button layout: A/B/X/Y face buttons, LB/LT/RB/RT shoulder buttons and triggers, L3/R3, View, Menu, Xbox button.",
            "Dual analog sticks with precise, low-latency input.",
            "Analog triggers ideal for racing and flight-simulation titles.",
            "Share button available as an extra input on Series X|S controllers.",
            "Compatible with Xbox Adaptive Controller accessories.",
            "Recommended for any system requiring a full 16-button layout.",
        ],
        isRecommended: true,
        imageAssetName: "controller-xbox-series"
    )

    /// Nintendo Switch Pro Controller
    public static let switchPro = ControllerGuideInfo(
        name: "Nintendo Switch Pro Controller",
        controllerType: .switchPro,
        supportedPlatforms: .all,
        pairingInstructions: [
            "Press and hold the Sync button (small button on the top of the controller) until the player indicators blink.",
            "On your iPhone/iPad or Apple TV, open Settings > Bluetooth.",
            "Select \"Pro Controller\" from the list of available devices.",
            "The player indicator LEDs will settle on one light once paired.",
            "Note: The Home and Capture buttons are not exposed to third-party apps.",
        ],
        featureNotes: [
            "Full button layout: B/A/Y/X face buttons, L/ZL/R/ZR shoulder buttons and triggers, L3/R3, +, −, Home, Capture.",
            "Dual analog sticks with comfortable ergonomics and accurate input.",
            "Motion controls (gyroscope/accelerometer) available via Game Controller framework.",
            "NFC reader present on controller hardware but not exposed via iOS API.",
            "Excellent battery life — up to 40 hours.",
            "Recommended for Nintendo system emulation (SNES, N64, GBA, DS, Switch).",
        ],
        isRecommended: true,
        imageAssetName: "controller-switch-pro"
    )

    /// Sony DualShock 4 (PS4)
    public static let dualShock4 = ControllerGuideInfo(
        name: "DualShock 4 Wireless Controller",
        controllerType: .dualShock4,
        supportedPlatforms: .all,
        pairingInstructions: [
            "Make sure your DualShock 4 is not connected to a PlayStation 4.",
            "Press and hold the PS button and the Share button simultaneously until the light bar blinks rapidly.",
            "On your iPhone/iPad or Apple TV, open Settings > Bluetooth.",
            "Select \"DUALSHOCK 4 Wireless Controller\" from the list of available devices.",
            "The light bar will turn solid blue once paired.",
        ],
        featureNotes: [
            "Full button layout: ✕/○/□/△ face buttons, L1/L2/R1/R2, L3/R3, Options, Share, PS button.",
            "Dual analog sticks and analog triggers supported.",
            "Touchpad gesture area not exposed via Apple Game Controller API.",
            "Light bar cannot be controlled from Provenance.",
            "Solid choice for PlayStation 1 emulation and earlier systems.",
        ],
        isRecommended: true,
        imageAssetName: "controller-dualshock4"
    )

    /// Generic Apple MFi certified controller
    public static let mfiStandard = ControllerGuideInfo(
        name: "MFi Game Controller",
        controllerType: .mfi,
        supportedPlatforms: .all,
        pairingInstructions: [
            "Put the MFi controller into pairing mode according to its manual (usually hold a pairing button).",
            "On your iPhone/iPad or Apple TV, open Settings > Bluetooth.",
            "Select your controller from the list of available devices.",
            "Once paired, the controller should be immediately recognized by Provenance.",
        ],
        featureNotes: [
            "Button layout varies by manufacturer — may be Extended (full) or Micro (limited).",
            "Extended layout: 4 face buttons, L1/L2/R1/R2, L3/R3, directional pad, 2 analog sticks.",
            "Micro layout: 4 face buttons, 2 shoulder buttons, directional pad only — not suitable for 3D games.",
            "Certified by Apple to meet minimum quality standards.",
            "Check your controller's specifications to confirm it has dual analog sticks before purchasing.",
            "Suitable for 8-bit and 16-bit systems with any layout; 3D systems require Extended layout.",
        ],
        isRecommended: false,
        imageAssetName: "controller-mfi-generic"
    )

    /// Apple Siri Remote (tvOS only)
    public static let siriRemote = ControllerGuideInfo(
        name: "Siri Remote",
        controllerType: .siriRemote,
        supportedPlatforms: .tvOS,
        pairingInstructions: [
            "The Siri Remote pairs automatically with Apple TV during setup.",
            "If re-pairing is needed, hold Menu + Volume Up for 5 seconds while near the Apple TV.",
            "No additional configuration is needed in Provenance — it is detected automatically.",
        ],
        featureNotes: [
            "Only 1–2 usable game buttons: Play/Pause (gen 1–2) or touchpad click (gen 3).",
            "Directional input via swipe gestures on the touch surface (gen 1–2) or d-pad ring (gen 3).",
            "Menu / Back button is RESERVED by tvOS — it cannot be remapped and always returns to the home screen.",
            "Gyroscope/accelerometer available for motion-based input.",
            "Suitable for: Atari 2600, Game & Watch, and other 1–2 button systems only.",
            "NOT suitable for: any system requiring Start/Select, shoulder buttons, or analog sticks.",
            "For the best tvOS experience, pair a DualSense, Xbox, or Switch Pro controller.",
        ],
        isRecommended: false,
        imageAssetName: "controller-siri-remote"
    )

    /// iCade Bluetooth arcade cabinet (legacy)
    public static let iCade = ControllerGuideInfo(
        name: "iCade Arcade Cabinet",
        controllerType: .iCade,
        supportedPlatforms: .iOS,
        pairingInstructions: [
            "Enable Bluetooth on your iPhone or iPad.",
            "Flip the power switch on the iCade to the ON position.",
            "Open the iCade app (required for initial setup) and follow the on-screen pairing steps.",
            "Once paired via the iCade app, the cabinet is available to Provenance.",
            "Enable iCade in Provenance Settings > Controllers > iCade.",
        ],
        featureNotes: [
            "8-directional joystick and 8 buttons (4 top row, 4 front row).",
            "Communicates via Bluetooth HID keyboard emulation — NOT the Game Controller framework.",
            "No analog sticks or analog triggers — digital inputs only.",
            "Legacy hardware — no longer manufactured; use modern controllers for new purchases.",
            "Best suited for arcade-style games: MAME, NES, SNES, Sega Genesis.",
            "Not supported on tvOS.",
        ],
        isRecommended: false,
        imageAssetName: "controller-icade"
    )
}

// MARK: - Filtering helpers

public extension ControllerCatalog {

    /// Controllers that support iOS
    static var iOSControllers: [ControllerGuideInfo] {
        all.filter { $0.supportsIOS }
    }

    /// Controllers that support tvOS
    static var tvOSControllers: [ControllerGuideInfo] {
        all.filter { $0.supportsTVOS }
    }

    /// Controllers marked as recommended
    static var recommendedControllers: [ControllerGuideInfo] {
        all.filter { $0.isRecommended }
    }

    /// Controllers grouped by type
    static let byType: [ControllerType: [ControllerGuideInfo]] =
        Dictionary(grouping: all, by: { $0.controllerType })

    /// Lookup a controller by its stable `id`
    static func controller(withID id: String) -> ControllerGuideInfo? {
        all.first { $0.id == id }
    }
}

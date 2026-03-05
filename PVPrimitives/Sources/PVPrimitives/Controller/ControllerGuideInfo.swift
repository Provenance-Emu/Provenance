//
//  ControllerGuideInfo.swift
//  PVPrimitives
//
//  Created by Provenance Emu on 2026-03-05.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

// MARK: - Controller Type

/// The hardware protocol / ecosystem a controller belongs to.
public enum ControllerType: String, CaseIterable, Codable, Sendable {
    /// Apple MFi (Made for iPhone/iPad) certified controllers
    case mfi = "MFi"
    /// Sony DualShock 4
    case dualShock4 = "DualShock 4"
    /// Sony DualSense (PS5)
    case dualSense = "DualSense"
    /// Microsoft Xbox Wireless controllers (Series S|X / One)
    case xbox = "Xbox Wireless"
    /// Nintendo Switch Pro Controller / Joy-Con
    case switchPro = "Nintendo Switch Pro"
    /// iCade (legacy Bluetooth HID)
    case iCade = "iCade"
    /// Apple Siri Remote (tvOS)
    case siriRemote = "Siri Remote"

    /// Human-readable display name
    public var displayName: String { rawValue }

    /// Whether this type is considered a modern, recommended controller
    public var isModern: Bool {
        switch self {
        case .dualSense, .xbox, .switchPro, .dualShock4: return true
        case .mfi, .iCade, .siriRemote: return false
        }
    }
}

// MARK: - Supported Platform

/// The Apple platform a controller can be used on.
public struct ControllerPlatformSupport: OptionSet, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let iOS   = ControllerPlatformSupport(rawValue: 1 << 0)
    public static let tvOS  = ControllerPlatformSupport(rawValue: 1 << 1)
    public static let all: ControllerPlatformSupport = [.iOS, .tvOS]
}

// MARK: - ControllerGuideInfo

/// Describes a hardware controller supported by Provenance.
///
/// This is a value-type data model intended for the Controller Guide UI. It is
/// not persisted to disk – populate it from `ControllerCatalog.all`.
public struct ControllerGuideInfo: Identifiable, Equatable, Sendable {

    // MARK: Properties

    /// Stable identifier derived from the controller name
    public var id: String { name.lowercased().replacingOccurrences(of: " ", with: "-") }

    /// Full marketing name (e.g. "DualSense Wireless Controller")
    public let name: String

    /// Hardware ecosystem / connection protocol
    public let controllerType: ControllerType

    /// Platforms this controller is supported on
    public let supportedPlatforms: ControllerPlatformSupport

    /// Step-by-step pairing instructions shown in the guide
    public let pairingInstructions: [String]

    /// Notable features such as extra buttons, analog triggers, haptics, etc.
    public let featureNotes: [String]

    /// Whether this controller is recommended for the best experience
    public let isRecommended: Bool

    /// Optional name of a bundled image asset used to illustrate the controller
    public let imageAssetName: String?

    // MARK: Init

    public init(
        name: String,
        controllerType: ControllerType,
        supportedPlatforms: ControllerPlatformSupport,
        pairingInstructions: [String],
        featureNotes: [String],
        isRecommended: Bool,
        imageAssetName: String? = nil
    ) {
        self.name = name
        self.controllerType = controllerType
        self.supportedPlatforms = supportedPlatforms
        self.pairingInstructions = pairingInstructions
        self.featureNotes = featureNotes
        self.isRecommended = isRecommended
        self.imageAssetName = imageAssetName
    }
}

// MARK: - Convenience

public extension ControllerGuideInfo {
    /// `true` when this controller supports iOS
    var supportsIOS: Bool { supportedPlatforms.contains(.iOS) }

    /// `true` when this controller supports tvOS
    var supportsTVOS: Bool { supportedPlatforms.contains(.tvOS) }
}

//
//  PVIndicatorTypes.swift
//  PVUIBase
//
//  Types and models for PVIndicatorLight — persistent HUD status dots.
//

import SwiftUI

// MARK: - Indicator ID

/// Unique identifiers for indicator lights in the HUD.
/// Used to register, update, and remove persistent status indicators.
public enum PVIndicatorID: String, CaseIterable {
    /// JIT compilation status indicator
    case jitStatus = "jit_status"
    /// Netplay ping/latency indicator (future)
    case netplayPing = "netplay_ping"
    /// Netplay bandwidth indicator (future)
    case netplayBandwidth = "netplay_bw"
    /// Network multiplayer player count (future)
    case playerCount = "player_count"
    /// PSX Analog mode toggle indicator
    case analogMode = "analog_mode"
    /// MFi+ modifier combo / swap mode active indicator
    case swapMode = "swap_mode"
}

// MARK: - Indicator State

/// Represents the visual state of an indicator light.
public struct PVIndicatorState: Equatable, Identifiable {
    public let id: PVIndicatorID
    public let color: PVIndicatorColor
    public let label: String
    public let description: String
    public let isVisible: Bool
    public let isPulsing: Bool

    public init(
        id: PVIndicatorID,
        color: PVIndicatorColor,
        label: String,
        description: String,
        isVisible: Bool = true,
        isPulsing: Bool = false
    ) {
        self.id = id
        self.color = color
        self.label = label
        self.description = description
        self.isVisible = isVisible
        self.isPulsing = isPulsing
    }

    public static func == (lhs: PVIndicatorState, rhs: PVIndicatorState) -> Bool {
        lhs.id == rhs.id &&
        lhs.color == rhs.color &&
        lhs.label == rhs.label &&
        lhs.description == rhs.description &&
        lhs.isVisible == rhs.isVisible &&
        lhs.isPulsing == rhs.isPulsing
    }
}

// MARK: - Indicator Color

/// Predefined colors for indicator lights with semantic meaning.
public enum PVIndicatorColor: Equatable {
    /// Green — active/good state
    case green
    /// Yellow — degraded/fallback state
    case yellow
    /// Red — error/unavailable state
    case red
    /// Gray — inactive/disabled state
    case gray
    /// Blue — informational state
    case blue

    /// The SwiftUI Color representation.
    public var swiftUIColor: Color {
        switch self {
        case .green:
            return Color(red: 0.2, green: 0.8, blue: 0.2)
        case .yellow:
            return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .red:
            return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .gray:
            return Color(white: 0.5)
        case .blue:
            return Color(red: 0.2, green: 0.5, blue: 1.0)
        }
    }

    /// Color for the pulsing glow effect.
    public var glowColor: Color {
        swiftUIColor.opacity(0.6)
    }
}

// MARK: - JIT Indicator States

/// Predefined states for the JIT indicator light.
public enum PVJITIndicatorState {
    /// JIT is active and functioning
    case active
    /// Running in interpreter/compatibility mode
    case interpreter
    /// JIT failed to initialize
    case failed
    /// Not applicable (e.g., on simulator or unsupported platform)
    case notApplicable

    /// The indicator state representation.
    public var indicatorState: PVIndicatorState {
        switch self {
        case .active:
            return PVIndicatorState(
                id: .jitStatus,
                color: .green,
                label: "Performance Mode Active",
                description: "JIT compilation is active. Games will run at full speed.",
                isVisible: true,
                isPulsing: false
            )
        case .interpreter:
            return PVIndicatorState(
                id: .jitStatus,
                color: .yellow,
                label: "Compatibility Mode",
                description: "Running in interpreter mode. Performance may be reduced.",
                isVisible: true,
                isPulsing: false
            )
        case .failed:
            return PVIndicatorState(
                id: .jitStatus,
                color: .red,
                label: "Performance Mode Unavailable",
                description: "JIT compilation could not be enabled. Check your device configuration.",
                isVisible: true,
                isPulsing: false
            )
        case .notApplicable:
            return PVIndicatorState(
                id: .jitStatus,
                color: .gray,
                label: "Performance Mode Not Available",
                description: "JIT is not available on this platform.",
                isVisible: false,
                isPulsing: false
            )
        }
    }
}

// MARK: - Analog Mode Indicator States

/// Predefined states for the PSX Analog mode indicator.
public enum PVAnalogModeIndicatorState {
    /// Analog mode is on (DualShock analog sticks active)
    case on
    /// Digital mode (D-pad only, no analog sticks)
    case off

    /// The indicator state representation.
    public var indicatorState: PVIndicatorState {
        switch self {
        case .on:
            return PVIndicatorState(
                id: .analogMode,
                color: .green,
                label: "Analog Mode",
                description: "PSX Analog mode is ON — left/right sticks active.",
                isVisible: true,
                isPulsing: false
            )
        case .off:
            return PVIndicatorState(
                id: .analogMode,
                color: .gray,
                label: "Digital Mode",
                description: "PSX Analog mode is OFF — D-pad only.",
                isVisible: false,
                isPulsing: false
            )
        }
    }
}

// MARK: - Swap Mode Indicator States

/// Predefined states for the MFi+ modifier / swap mode indicator.
public enum PVSwapModeIndicatorState {
    /// Modifier combo is currently held (transient)
    case active
    /// No modifier combo held
    case inactive

    /// The indicator state representation.
    public var indicatorState: PVIndicatorState {
        switch self {
        case .active:
            return PVIndicatorState(
                id: .swapMode,
                color: .blue,
                label: "MFi+ Active",
                description: "Modifier combo held — extended inputs available.",
                isVisible: true,
                isPulsing: true
            )
        case .inactive:
            return PVIndicatorState(
                id: .swapMode,
                color: .gray,
                label: "MFi+ Inactive",
                description: "Release modifier combo.",
                isVisible: false,
                isPulsing: false
            )
        }
    }
}

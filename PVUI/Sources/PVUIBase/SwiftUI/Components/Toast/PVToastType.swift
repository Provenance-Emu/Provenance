//
//  PVToastType.swift
//  PVUI
//
//  Created by Claude on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

/// Types of in-game toast notifications, each with distinct visual styling
public enum PVToastType: String, CaseIterable, Sendable {
    case info
    case success
    case warning
    case error
    case jit
    case achievement

    // MARK: - Visual Properties

    /// Primary accent color for this toast type
    public var color: Color {
        switch self {
        case .info:        return RetroTheme.retroBlue
        case .success:     return RetroTheme.retroGreen
        case .warning:     return .orange
        case .error:       return Color(red: 0.95, green: 0.22, blue: 0.22)
        case .jit:         return RetroTheme.retroPurple
        case .achievement: return Color(red: 1.0, green: 0.84, blue: 0.0) // gold
        }
    }

    /// SF Symbol name used as the default icon for this toast type
    public var defaultIcon: String {
        switch self {
        case .info:        return "info.circle.fill"
        case .success:     return "checkmark.circle.fill"
        case .warning:     return "exclamationmark.triangle.fill"
        case .error:       return "xmark.circle.fill"
        case .jit:         return "bolt.fill"
        case .achievement: return "trophy.fill"
        }
    }

    /// Accessibility label describing the toast type for VoiceOver
    public var accessibilityLabel: String {
        switch self {
        case .info:        return "Info"
        case .success:     return "Success"
        case .warning:     return "Warning"
        case .error:       return "Error"
        case .jit:         return "JIT"
        case .achievement: return "Achievement"
        }
    }
}

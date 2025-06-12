//
//  AlertMessage.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Foundation
import SwiftUI

/// Represents an alert message to be displayed
public struct AlertMessage: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let type: AlertType
    public var sound: ButtonSound? = .click // Default sound
    
    /// Defines the type of alert for styling and sound effects
    public enum AlertType: String, CaseIterable, Equatable {
        case info
        case warning
        case error
        case success
        
        var iconName: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return RetroTheme.retroBlue
            case .warning: return .orange
            case .error: return RetroTheme.retroPink
            case .success: return .retroGreen
            }
        }
    }
    
    // Equatable conformance
    public static func == (lhs: AlertMessage, rhs: AlertMessage) -> Bool { lhs.id == rhs.id }
}

//
//  RetroWaveColors.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import SwiftUI

// MARK: - Retrowave Design System

// Retrowave color palette
public extension Color {
    public static let retroPink = Color(red: 0.98, green: 0.2, blue: 0.6)
    public static let retroPurple = Color(red: 0.5, green: 0.0, blue: 0.8)
    public static let retroBlue = Color(red: 0.0, green: 0.8, blue: 0.95)
    public static let retroYellow = Color(red: 0.98, green: 0.84, blue: 0.2)
    public static let retroOrange = Color(red: 0.98, green: 0.5, blue: 0.2)
    public static let retroBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
    
    // Gradient helpers
    public static let retroSunset = LinearGradient(
        gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let retroGrid = LinearGradient(
        gradient: Gradient(colors: [.retroBlue.opacity(0.7), .retroPurple.opacity(0.7)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let retroNeon = LinearGradient(
        gradient: Gradient(colors: [.retroPink, .retroPurple]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let retroCyber = LinearGradient(
        gradient: Gradient(colors: [.retroBlue, .retroPurple]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Gradient helpers
    public static let retroGradient = LinearGradient(
        gradient: Gradient(colors: [.retroPurple, .retroPink]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let retroSunsetGradient = LinearGradient(
        gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
        startPoint: .top,
        endPoint: .bottom
    )
}

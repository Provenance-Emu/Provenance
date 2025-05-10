//
//  RetroViewModifiers.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import Perception

/// RetroViewModifiers provides reusable view modifiers for RetroWave styling
public struct RetroViewModifiers {
    
    /// Applies RetroWave card styling to a view
    public struct RetroCardModifier: ViewModifier {
        /// The opacity of the background
        let opacity: Double
        
        /// Initialize a new RetroCardModifier
        /// - Parameter opacity: The opacity of the background (default: 0.3)
        public init(opacity: Double = 0.3) {
            self.opacity = opacity
        }
        
        public func body(content: Content) -> some View {
            content
                .padding()
                .background(Color.retroBlack.opacity(opacity))
                .cornerRadius(10)
        }
    }
    
    /// Applies RetroWave section header styling to a view
    public struct RetroSectionHeaderModifier: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .font(.headline)
                .foregroundColor(.retroPink)
                .padding(.bottom, 4)
        }
    }
    
    /// Applies RetroWave button styling to a view
    public struct RetroButtonModifier: ViewModifier {
        /// The gradient colors for the button
        let colors: [Color]
        
        /// Initialize a new RetroButtonModifier
        /// - Parameter colors: The gradient colors for the button (default: retroBlue, retroPurple)
        public init(colors: [Color] = [.retroBlue, .retroPurple]) {
            self.colors = colors
        }
        
        public func body(content: Content) -> some View {
            content
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: colors.map { $0.opacity(0.7) }),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
                .foregroundColor(.white)
                .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 4, x: 0, y: 0)
        }
    }
    
    /// Applies RetroWave glowing border to a view
    public struct RetroGlowingBorderModifier: ViewModifier {
        /// The color of the border
        let color: Color
        
        /// The width of the border
        let lineWidth: CGFloat
        
        /// Whether the animation is enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        
        /// Initialize a new RetroGlowingBorderModifier
        /// - Parameters:
        ///   - color: The color of the border (default: retroPink)
        ///   - lineWidth: The width of the border (default: 1.0)
        public init(color: Color = .retroPink, lineWidth: CGFloat = 1.0) {
            self.color = color
            self.lineWidth = lineWidth
        }
        
        public func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: lineWidth)
                        .shadow(color: color.opacity(0.8), radius: reduceMotion ? 2 : 4, x: 0, y: 0)
                        .animation(
                            reduceMotion ? nil : Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: reduceMotion ? 0 : 1
                        )
                )
        }
    }
    
    /// Applies RetroWave badge styling to a view
    public struct RetroBadgeModifier: ViewModifier {
        /// The color of the badge
        let color: Color
        
        /// Initialize a new RetroBadgeModifier
        /// - Parameter color: The color of the badge (default: retroBlue)
        public init(color: Color = .retroBlue) {
            self.color = color
        }
        
        public func body(content: Content) -> some View {
            content
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.7))
                .cornerRadius(4)
                .foregroundColor(.white)
                .shadow(color: color.opacity(0.5), radius: 2, x: 0, y: 0)
        }
    }
    
    /// Applies RetroWave progress bar styling to a view
    public struct RetroProgressModifier: ViewModifier {
        /// The progress value (0.0-1.0)
        let progress: Double
        
        /// The height of the progress bar
        let height: CGFloat
        
        /// Whether the animation is enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        
        /// Initialize a new RetroProgressModifier
        /// - Parameters:
        ///   - progress: The progress value (0.0-1.0)
        ///   - height: The height of the progress bar (default: 12.0)
        public init(progress: Double, height: CGFloat = 12.0) {
            self.progress = progress
            self.height = height
        }
        
        public func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            Rectangle()
                                .fill(Color.retroBlack.opacity(0.5))
                                .frame(height: height)
                                .cornerRadius(height / 2)
                            
                            // Progress fill
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroBlue, .retroPurple, .retroPink]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, CGFloat(progress) * geometry.size.width), height: height)
                                .cornerRadius(height / 2)
                            
                            // Glow effect (only if motion is not reduced)
                            if !reduceMotion && progress > 0.02 {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.clear, .retroPink.opacity(0.5), .clear]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 20, height: height)
                                    .cornerRadius(height / 2)
                                    .offset(x: max(0, CGFloat(progress) * geometry.size.width - 20))
                                    .animation(
                                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                        value: progress
                                    )
                            }
                        }
                    }
                )
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Apply RetroWave card styling
    /// - Parameter opacity: The opacity of the background
    /// - Returns: A styled view
    func retroCard(opacity: Double = 0.3) -> some View {
        modifier(RetroViewModifiers.RetroCardModifier(opacity: opacity))
    }
    
    /// Apply RetroWave section header styling
    /// - Returns: A styled view
    func retroSectionHeader() -> some View {
        modifier(RetroViewModifiers.RetroSectionHeaderModifier())
    }
    
    /// Apply RetroWave button styling
    /// - Parameter colors: The gradient colors for the button
    /// - Returns: A styled view
    func retroButton(colors: [Color] = [.retroBlue, .retroPurple]) -> some View {
        modifier(RetroViewModifiers.RetroButtonModifier(colors: colors))
    }
    
    /// Apply RetroWave glowing border
    /// - Parameters:
    ///   - color: The color of the border
    ///   - lineWidth: The width of the border
    /// - Returns: A styled view
    func retroGlowingBorder(color: Color = .retroPink, lineWidth: CGFloat = 1.0) -> some View {
        modifier(RetroViewModifiers.RetroGlowingBorderModifier(color: color, lineWidth: lineWidth))
    }
    
    /// Apply RetroWave badge styling
    /// - Parameter color: The color of the badge
    /// - Returns: A styled view
    func retroBadge(color: Color = .retroBlue) -> some View {
        modifier(RetroViewModifiers.RetroBadgeModifier(color: color))
    }
    
    /// Apply RetroWave progress bar styling
    /// - Parameters:
    ///   - progress: The progress value (0.0-1.0)
    ///   - height: The height of the progress bar
    /// - Returns: A styled view
    func retroProgress(progress: Double, height: CGFloat = 12.0) -> some View {
        modifier(RetroViewModifiers.RetroProgressModifier(progress: progress, height: height))
    }
}

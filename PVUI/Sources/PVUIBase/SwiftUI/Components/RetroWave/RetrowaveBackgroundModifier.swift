//
//  RetrowaveBackgroundModifier.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import SwiftUI

// MARK: - Retrowave Background Modifier

/// A view modifier that applies a retro-style background with grid lines and scanline effects
public struct RetrowaveBackgroundModifier: ViewModifier {
    @State private var scanlineOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.7
    
    let lineSpacing: CGFloat
    let lineColor: Color
    
    public init(lineSpacing: CGFloat = 30, lineColor: Color = Color.retroBlue.opacity(0.2)) {
        self.lineSpacing = lineSpacing
        self.lineColor = lineColor
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            // Base background
            Color.retroBlack.ignoresSafeArea()
            
            // Sunset gradient
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.retroCyber)
                    .frame(height: 200)
                    .offset(y: 100)
                    .blur(radius: 30)
            }
            .ignoresSafeArea()
            
            // Grid lines
            RetroGrid(lineSpacing: lineSpacing, lineColor: lineColor)
                .ignoresSafeArea()
            
            // Scanline effect
            VStack(spacing: 4) {
                ForEach(0..<100) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 1)
                }
            }
            .offset(y: scanlineOffset)
            .ignoresSafeArea()
            
            // Content
            content
        }
        .onAppear {
            // Scanline animation
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                scanlineOffset = 4
            }
            
            // Pulsing glow effect
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

// Extension to make the modifier easier to use
public extension View {
    /// Applies a retro-style background with grid lines and scanline effects
    /// - Parameters:
    ///   - lineSpacing: The spacing between grid lines
    ///   - lineColor: The color of the grid lines
    /// - Returns: A view with the retrowave background applied
    public func retrowaveBackground(lineSpacing: CGFloat = 30, lineColor: Color = Color.retroBlue.opacity(0.2)) -> some View {
        self.modifier(RetrowaveBackgroundModifier(lineSpacing: lineSpacing, lineColor: lineColor))
    }
}

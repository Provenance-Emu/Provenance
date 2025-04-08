///
/// NoConsolesView.swift
/// PVUI
///
/// Created by Joseph Mattiello on 9/22/24.
/// Updated with retrowave styling on 04/07/25.
///

import SwiftUI
import PVThemes
import AnimatedGradient

/// Animated gradient background for the NoConsolesView
public struct PVAnimatedGradient: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public var body: some View {
        AnimatedLinearGradient(colors: [
            Color.retroPink,
            Color.retroPurple,
            Color.retroBlue,
            Color.retroDarkBlue])
        .numberOfSimultaneousColors(3)
        .setAnimation(.bouncy(duration: 5))
        .gradientPoints(start: .topTrailing, end: .bottomLeading)
        .ignoresSafeArea()
    }
}

/// A retrowave-styled view displayed when no games are found
public struct NoConsolesView: SwiftUI.View {
    /// Delegate to handle user actions
    weak var delegate: PVMenuDelegate!
    
    /// Animation state for glow effect
    @State private var glowOpacity: Double = 0.7
    
    /// Animation state for title
    @State private var titleOffset: CGFloat = -10
    
    public var body: some SwiftUI.View {
        ZStack {
            // Background
            if #available(iOS 18.0, *) {
                ProvenanceAnimatedBackgroundView()
            } else {
                PVAnimatedGradient()
            }
            
            // Grid pattern
            RetroGridPattern()
                .opacity(0.3)
            
            // Content container
            VStack(spacing: 30) {
                // Title with animation
                Text("NO GAMES FOUND")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(0.8)
                    )
                    .overlay(
                        Rectangle()
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPink]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.retroPink.opacity(glowOpacity), radius: 10, x: 0, y: 0)
                    .offset(y: titleOffset)
                
                // Description text
                Text("Import games to start playing")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 10)
                
                // Add Games button with retrowave styling
                Button(action: {
                    delegate?.didTapAddGames()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.square.fill.on.square.fill")
                            .font(.system(size: 18))
                        Text("ADD GAMES")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .cornerRadius(8)
                    .shadow(color: Color.retroBlue.opacity(glowOpacity), radius: 10, x: 0, y: 0)
                }
            }
            .padding(30)
            .onAppear {
                // Animate glow effect
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.4
                }
                
                // Animate title
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    titleOffset = 10
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    NoConsolesView()
}
#endif

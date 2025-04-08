//
//  RetroGlowText.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/7/25.
//

import SwiftUI

/// A view that displays glowing text with retrowave styling
public struct RetroGlowText: View {
    public let text: String
    public let fontSize: CGFloat
    @State private var glowOpacity: Double = 0.7
    
    public init(_ text: String, fontSize: CGFloat = 24) {
        self.text = text
        self.fontSize = fontSize
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
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
            .shadow(color: .retroPink.opacity(glowOpacity), radius: 10, x: 0, y: 0)
            .onAppear {
                // Animate glow effect
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.4
                }
            }
    }
}

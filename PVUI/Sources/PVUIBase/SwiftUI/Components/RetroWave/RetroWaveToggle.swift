//
//  RetroWaveToggle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI
import PVThemes

/// A custom toggle with retrowave styling
public struct RetroWaveToggle: View {
    @Binding var isOn: Bool
    let label: String
    
    @State private var isDragging = false
    @State private var glowOpacity = 0.0
    
    public init(isOn: Binding<Bool>, label: String) {
        self._isOn = isOn
        self.label = label
    }
    
    public var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
                .font(.system(size: 16))
            
            Spacer()
            
            // Custom toggle
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? RetroTheme.retroPink.opacity(0.3) : Color.black.opacity(0.6))
                    .frame(width: 60, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isOn ? RetroTheme.retroPink : RetroTheme.retroBlue.opacity(0.5),
                                lineWidth: 1.5
                            )
                    )
                
                // Thumb
                Circle()
                    .fill(isOn ? RetroTheme.retroPink : RetroTheme.retroBlue)
                    .frame(width: 26, height: 26)
                    .shadow(color: isOn ? RetroTheme.retroPink.opacity(glowOpacity) : Color.clear, radius: 6)
                    .offset(x: isOn ? 13 : -13)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isOn)
            }
            .onTapGesture {
                isOn.toggle()
                
                // Animate glow when turned on
                if isOn {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        glowOpacity = 0.8
                    }
                } else {
                    glowOpacity = 0.0
                }
            }
            .onAppear {
                // Set initial glow state
                if isOn {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        glowOpacity = 0.8
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RetroWaveToggle(isOn: .constant(true), label: "Enable Feature")
        RetroWaveToggle(isOn: .constant(false), label: "Disable Feature")
    }
    .padding()
    .background(RetroTheme.retroBlack)
}

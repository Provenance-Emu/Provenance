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
    
#if os(tvOS)
    @FocusState private var isFocused: Bool
#endif
    
    public init(isOn: Binding<Bool>, label: String) {
        self._isOn = isOn
        self.label = label
    }
    
    public var body: some View {
#if os(tvOS)
        // tvOS: Use Button for proper focus navigation
        Button(action: toggleAction) {
            HStack {
                Text(label)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                
                Spacer()
                
                // Custom toggle
                toggleView
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? RetroTheme.retroPink.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isFocused ? RetroTheme.retroPink : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            setupInitialGlow()
        }
#else
        // iOS/macOS: Use tap gesture
        HStack {
            Text(label)
                .foregroundColor(.white)
                .font(.system(size: 16))
            
            Spacer()
            
            // Custom toggle
            toggleView
                .onTapGesture {
                    toggleAction()
                }
        }
        .onAppear {
            setupInitialGlow()
        }
#endif
    }
    
    private var toggleView: some View {
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
    }
    
    private func toggleAction() {
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
    
    private func setupInitialGlow() {
        // Set initial glow state
        if isOn {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
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

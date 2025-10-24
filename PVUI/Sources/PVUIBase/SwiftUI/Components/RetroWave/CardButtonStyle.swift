//
//  CardButtonStyle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVLogging

/// A button style optimized for tvOS focus handling with retrowave styling
public struct CardButtonStyle: ButtonStyle {
    #if os(tvOS)
    @State private var isFocused = false
    #endif
    
    /// Creates a new CardButtonStyle
    public init() {}
    
    /// Makes the button body with proper focus handling for tvOS
    public func makeBody(configuration: Configuration) -> some View {
        #if os(tvOS)
        CardButtonContent(configuration: configuration)
            .onAppear {
                DLOG("CardButtonStyle appeared")
            }
        #else
        // iOS version - simpler without focus handling
        configuration.label
            .foregroundColor(.white)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        #endif
    }
}

#if os(tvOS)
/// Content view for the CardButtonStyle on tvOS
struct CardButtonContent: View {
    let configuration: ButtonStyle.Configuration
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        configuration.label
            .foregroundColor(.white)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .focusable(true)
            .buttonBorderShape(.roundedRectangle)
            .shadow(color: .retroPink.opacity(0.5), radius: 5, x: 0, y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isFocused ?
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ) : LinearGradient(
                                gradient: Gradient(colors: [Color.clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                        lineWidth: isFocused ? 4 : 0
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
    }
}
#endif

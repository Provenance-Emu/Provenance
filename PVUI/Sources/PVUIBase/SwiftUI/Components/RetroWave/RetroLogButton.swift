//
//  RetroLogButton.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/26/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVLogging

/// A button that presents a RetroLogView in fullscreen mode
public struct RetroLogButton: View {
    // MARK: - Properties
    
    /// Controls whether the log view is presented
    @State private var showLogView = false
    
    /// Custom label for the button
    private let label: AnyView
    
    /// Custom size for the button
    private let size: CGFloat
    
    /// Custom color for the button
    private let color: Color
    
    // MARK: - Initialization
    
    /// Initialize with default settings
    public init() {
        self.size = 16
        self.color = RetroTheme.retroBlue
        self.label = AnyView(
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(RetroTheme.retroBlue)
        )
    }
    
    /// Initialize with custom size and color
    public init(size: CGFloat = 16, color: Color = RetroTheme.retroBlue) {
        self.size = size
        self.color = color
        self.label = AnyView(
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: size))
                .foregroundColor(color)
        )
    }
    
    /// Initialize with custom view
    public init<Content: View>(@ViewBuilder label: () -> Content) {
        self.size = 16
        self.color = RetroTheme.retroBlue
        self.label = AnyView(label())
    }
    
    // MARK: - Body
    
    public var body: some View {
        Button {
            showLogView = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showLogView) {
            ZStack {
                // Background
                Color.black.opacity(0.95)
                    .edgesIgnoringSafeArea(.all)
                
                // Log view
                RetroLogView(isFullscreen: $showLogView)
                    .padding()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RetroLogButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Default button
            RetroLogButton()
            
            // Custom size and color
            RetroLogButton(size: 24, color: RetroTheme.retroPink)
            
            // Custom label
            RetroLogButton {
                HStack {
                    Image(systemName: "terminal")
                    Text("Logs")
                }
                .foregroundColor(RetroTheme.retroPurple)
            }
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif

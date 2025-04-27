//
//  StatusControlButton.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/26/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLogging
import PVThemes

/// A button that displays a fullscreen RetroStatusControlView when tapped
public struct StatusControlButton: View {
    // MARK: - Properties
    
    /// The size of the button
    private let size: CGFloat
    
    /// The color of the button
    private let color: Color
    
    /// State to control the sheet presentation
    @State private var showStatusControl = false
    
    // MARK: - Initialization
    
    /// Initialize a new status control button
    /// - Parameters:
    ///   - size: The size of the button (default: 12)
    ///   - color: The color of the button (default: .retroPurple)
    public init(size: CGFloat = 12, color: Color = .retroPurple) {
        self.size = size
        self.color = color
    }
    
    // MARK: - Body
    
    public var body: some View {
        Button(action: {
            DLOG("Status control button tapped")
            showStatusControl = true
        }) {
            // Display different gauge icons based on the cumulative progress
            Image(systemName: viewModel.gaugeIconName)
                .font(.system(size: size))
                .foregroundColor(color)
        }
        .fullScreenCover(isPresented: $showStatusControl) {
            StatusControlFullscreenView(isPresented: $showStatusControl)
        }
    }
}

/// A fullscreen view that displays the RetroStatusControlView
private struct StatusControlFullscreenView: View {
    // MARK: - Properties
    
    /// Binding to control the presentation of the view
    @Binding var isPresented: Bool
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9).edgesIgnoringSafeArea(.all)
            
            // Content
            VStack {
                // Header with close button
                HStack {
                    Text("System Status")
                        .font(.title)
                        .foregroundColor(.retroPink)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.retroBlue)
                    }
                }
                .padding()
                
                // Status control view
                RetroStatusControlView()
                    .padding()
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    StatusControlButton()
}

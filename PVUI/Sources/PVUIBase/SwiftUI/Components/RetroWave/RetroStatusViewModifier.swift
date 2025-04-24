//
//  RetroStatusViewModifier.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

/// A view modifier that adds the RetroStatusControlView to any view
public struct RetroStatusViewModifier: ViewModifier {
    @State private var isVisible: Bool = true
    @State private var lastStatusChange = Date()
    
    // Configurable properties
    private let position: Position
    private let autoHide: Bool
    private let autoHideDelay: TimeInterval
    
    /// Position of the status view
    public enum Position {
        case top
        case bottom
    }
    
    /// Initialize the modifier with configuration options
    /// - Parameters:
    ///   - position: Position of the status view (top or bottom)
    ///   - autoHide: Whether to automatically hide the view after a delay
    ///   - autoHideDelay: Delay in seconds before hiding the view
    public init(
        position: Position = .bottom,
        autoHide: Bool = false,
        autoHideDelay: TimeInterval = 5.0
    ) {
        self.position = position
        self.autoHide = autoHide
        self.autoHideDelay = autoHideDelay
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            if isVisible {
                VStack {
                    if position == .bottom {
                        Spacer()
                    }
                    
                    RetroStatusControlView()
                        .transition(.move(edge: position == .top ? .top : .bottom))
                    
                    if position == .top {
                        Spacer()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isVisible)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WebServerUploadProgress"))) { _ in
            showStatusView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WebServerUploadCompleted"))) { _ in
            showStatusView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WebServerStatusChanged"))) { _ in
            showStatusView()
        }
        .onReceive(NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryStarted)) { _ in
            showStatusView()
        }
        .onReceive(NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryProgress)) { _ in
            showStatusView()
        }
        .onReceive(NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryCompleted)) { _ in
            showStatusView()
        }
    }
    
    /// Show the status view and start the auto-hide timer if configured
    private func showStatusView() {
        withAnimation {
            isVisible = true
        }
        
        lastStatusChange = Date()
        
        if autoHide {
            // Start a timer to hide the view after the delay
            DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay) {
                // Only hide if no new status changes have occurred during the delay
                if Date().timeIntervalSince(lastStatusChange) >= autoHideDelay {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Add a RetroStatusControlView to the view
    /// - Parameters:
    ///   - position: Position of the status view (top or bottom)
    ///   - autoHide: Whether to automatically hide the view after a delay
    ///   - autoHideDelay: Delay in seconds before hiding the view
    /// - Returns: A view with the RetroStatusControlView added
    func withRetroStatusView(
        position: RetroStatusViewModifier.Position = .bottom,
        autoHide: Bool = false,
        autoHideDelay: TimeInterval = 5.0
    ) -> some View {
        self.modifier(RetroStatusViewModifier(
            position: position,
            autoHide: autoHide,
            autoHideDelay: autoHideDelay
        ))
    }
}

// MARK: - Preview
#if DEBUG
struct RetroStatusViewModifier_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Provenance")
                    .font(.largeTitle)
                    .foregroundColor(RetroTheme.retroPink)
                
                Spacer()
            }
            .padding()
        }
        .withRetroStatusView()
    }
}
#endif

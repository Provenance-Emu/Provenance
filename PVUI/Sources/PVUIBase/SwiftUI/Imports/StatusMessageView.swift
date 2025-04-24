//
//  StatusMessageView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

/// A view that displays status messages and progress
public struct StatusMessageView: View {
    @ObservedObject private var messageManager = StatusMessageManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Animation states
    @State private var glowOpacity: Double = 0.7
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 4) {
            // Progress views for various operations
            Group {
                // File recovery progress
                if let progress = messageManager.fileRecoveryProgress {
                    progressView(title: "File Recovery", current: progress.current, total: progress.total, color: RetroTheme.retroBlue)
                }
                
                // ROM scanning progress
                if let progress = messageManager.viewModel.romScanningProgress {
                    progressView(title: "ROM Scanning", current: progress.current, total: progress.total, color: RetroTheme.retroPurple)
                }
                
                // Temporary file cleanup progress
                if let progress = messageManager.viewModel.temporaryFileCleanupProgress {
                    progressView(title: "File Cleanup", current: progress.current, total: progress.total, color: RetroTheme.retroPink)
                }
                
                // Cache management progress
                if let progress = messageManager.viewModel.cacheManagementProgress {
                    progressView(title: "Cache Optimization", current: progress.current, total: progress.total, color: RetroTheme.retroBlue)
                }
                
                // Download progress
                if let progress = messageManager.viewModel.downloadProgress {
                    progressView(title: "Download", current: progress.current, total: progress.total, color: RetroTheme.retroPurple)
                }
                
                // CloudKit sync progress
                if let progress = messageManager.viewModel.cloudKitSyncProgress {
                    progressView(title: "CloudKit Sync", current: progress.current, total: progress.total, color: RetroTheme.retroPink)
                }
            }
            
            // Status messages
            ForEach(messageManager.messages) { message in
                statusMessageView(message)
            }
        }
        .frame(maxWidth: .infinity) // Make the view take up full width
        .padding(10) // Match the search bar's internal padding
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
        )
        .onAppear {
            // Start retrowave animations
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
    
    /// Creates a view for a status message
    /// - Parameter message: The message to display
    /// - Returns: A view for the message
    @ViewBuilder
    private func statusMessageView(_ message: StatusMessage) -> some View {
        HStack {
            Circle()
                .fill(messageTypeColor(message.type))
                .frame(width: 10, height: 10)
                .shadow(color: messageTypeColor(message.type).opacity(glowOpacity), radius: 3, x: 0, y: 0)
            
            Text(message.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                messageManager.removeMessage(withID: message.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [messageTypeColor(message.type), RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: messageTypeColor(message.type).opacity(0.5), radius: 3, x: 0, y: 0)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.3), value: messageManager.messages)
    }
    
    /// Creates a generic progress view for any operation
    /// - Parameters:
    ///   - title: Title of the operation
    ///   - current: Current progress value
    ///   - total: Total progress value
    ///   - color: Primary color for the progress view
    /// - Returns: A progress view
    @ViewBuilder
    private func progressView(title: String, current: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                
                Spacer()
                
                Text("\(current)/\(total) (\(Int(Double(current) / Double(total) * 100))%)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, RetroTheme.retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(CGFloat(current) / CGFloat(total) * geometry.size.width, geometry.size.width)), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [color, RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 0)
    }
    
    /// Get the color for a message type
    /// - Parameter type: The message type
    /// - Returns: The appropriate color
    private func messageTypeColor(_ type: StatusMessage.MessageType) -> Color {
        switch type {
        case .info:
            return RetroTheme.retroBlue
        case .success:
            return Color.green
        case .warning:
            return Color.orange
        case .error:
            return RetroTheme.retroPink
        case .progress:
            return RetroTheme.retroPurple
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        StatusMessageView()
            .padding()
        
        Button("Add Message") {
            StatusMessageManager.shared.addInfo("This is an info message")
        }
        
        Button("Add Success") {
            StatusMessageManager.shared.addSuccess("This is a success message")
        }
        
        Button("Add Warning") {
            StatusMessageManager.shared.addWarning("This is a warning message")
        }
        
        Button("Add Error") {
            StatusMessageManager.shared.addError("This is an error message")
        }
        
        Button("Add Progress") {
            StatusMessageManager.shared.addProgress("This is a progress message")
        }
        
        Button("Set Progress") {
            StatusMessageManager.shared.updateFileRecoveryProgress(current: 75, total: 100)
        }
        
        Button("Clear Progress") {
            StatusMessageManager.shared.clearFileRecoveryProgress()
        }
    }
    .padding()
    .background(RetroTheme.retroDarkBlue)
}
#endif

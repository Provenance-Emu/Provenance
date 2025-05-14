//
//  RetroMessageRow.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVUIBase

/// A row displaying a status message with retrowave styling
public struct RetroMessageRow: View {
    // MARK: - Properties
    
    /// The message to display
    let message: StatusMessageManager.StatusMessage
    
    /// Function to format time intervals
    let formatTimeInterval: (Date) -> String
    
    /// Function to determine message type color
    let messageTypeColor: (StatusMessageManager.StatusMessage.MessageType) -> Color
    
    /// Animation state for hover effect
    @State private var isHovering = false
    
    // MARK: - Body
    
    // Check if this is a CloudKit sync message
    private var isCloudKitMessage: Bool {
        message.message.contains("CloudKit") || message.message.contains("iCloud")
    }
    
    // Get icon for message type
    private var messageIcon: String {
        if isCloudKitMessage {
            return "icloud"
        }
        
        switch message.type {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .progress: return "arrow.clockwise.circle"
        }
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Status indicator with appropriate icon and glow effect
            if isCloudKitMessage {
                // Special styling for CloudKit messages
                Image(systemName: messageIcon)
                    .font(.system(size: 12))
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
            } else {
                // Standard status indicator
                Circle()
                    .fill(messageTypeColor(message.type))
                    .frame(width: 10, height: 10)
                    .shadow(color: messageTypeColor(message.type).opacity(0.7), radius: 3, x: 0, y: 0)
            }
            
            // Message text with retrowave styling
            Text(message.message)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isCloudKitMessage ? RetroTheme.retroBlue.opacity(0.9) : Color.white.opacity(0.9))
                .shadow(color: (isCloudKitMessage ? RetroTheme.retroBlue : messageTypeColor(message.type)).opacity(0.5), radius: 1, x: 0, y: 0)
                .lineLimit(1)
            
            Spacer()
            
            // Timestamp with retrowave styling
            Text(formatTimeInterval(message.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor((isCloudKitMessage ? RetroTheme.retroBlue : messageTypeColor(message.type)).opacity(0.8))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isCloudKitMessage ? Color.black.opacity(0.6) : Color.black.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isCloudKitMessage 
                        ? RetroTheme.retroBlue.opacity(isHovering ? 0.9 : 0.5)
                        : messageTypeColor(message.type).opacity(isHovering ? 0.8 : 0.3),
                    lineWidth: isCloudKitMessage ? 1.5 : 1
                )
        )
        // Add subtle grid pattern for CloudKit messages
        .overlay(
            Group {
                if isCloudKitMessage {
                    RetroTheme.RetroGridView().opacity(0.15)
                } else {
                    Color.clear
                }
            }
        )
        #if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        #endif
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

#if DEBUG
struct RetroMessageRow_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            RetroMessageRow(
                message: StatusMessageManager.StatusMessage(message: "Test message", type: .info),
                formatTimeInterval: { _ in "2m ago" },
                messageTypeColor: { type in
                    switch type {
                    case .info: return RetroTheme.retroBlue
                    case .success: return Color.green
                    case .warning: return Color.orange
                    case .error: return RetroTheme.retroPink
                    case .progress: return RetroTheme.retroPurple
                    }
                }
            )
            .padding()
        }
    }
}
#endif

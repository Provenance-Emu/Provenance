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
    let message: StatusMessage
    
    /// Function to format time intervals
    let formatTimeInterval: (Date) -> String
    
    /// Function to determine message type color
    let messageTypeColor: (StatusMessage.MessageType) -> Color
    
    /// Animation state for hover effect
    @State private var isHovering = false
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 8) {
            // Status indicator with glow effect
            Circle()
                .fill(messageTypeColor(message.type))
                .frame(width: 10, height: 10)
                .shadow(color: messageTypeColor(message.type).opacity(0.7), radius: 3, x: 0, y: 0)
            
            // Message text with retrowave styling
            Text(message.message)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.9))
                .shadow(color: messageTypeColor(message.type).opacity(0.5), radius: 1, x: 0, y: 0)
                .lineLimit(1)
            
            Spacer()
            
            // Timestamp with retrowave styling
            Text(formatTimeInterval(message.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(messageTypeColor(message.type).opacity(0.8))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    messageTypeColor(message.type).opacity(isHovering ? 0.8 : 0.3),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
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
                message: StatusMessage(message: "Test message", type: .info),
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

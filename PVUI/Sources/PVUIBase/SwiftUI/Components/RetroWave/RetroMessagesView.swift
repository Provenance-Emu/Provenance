//
//  RetroMessagesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVUIBase

/// A view displaying status messages with retrowave styling
public struct RetroMessagesView: View {
    // MARK: - Properties
    
    /// The messages to display
    let messages: [StatusMessage]
    
    /// Function to format time intervals
    let formatTimeInterval: (Date) -> String
    
    /// Function to determine message type color
    let messageTypeColor: (StatusMessage.MessageType) -> Color
    
    // MARK: - Initialization
    
    /// Creates a new RetroMessagesView
    /// - Parameters:
    ///   - messages: The messages to display
    ///   - formatTimeInterval: Function to format time intervals
    ///   - messageTypeColor: Function to determine message type color
    public init(
        messages: [StatusMessage],
        formatTimeInterval: @escaping (Date) -> String,
        messageTypeColor: @escaping (StatusMessage.MessageType) -> Color
    ) {
        self.messages = messages
        self.formatTimeInterval = formatTimeInterval
        self.messageTypeColor = messageTypeColor
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title for messages section
            HStack {
                Text("RECENT MESSAGES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
                
                Spacer()
                
                Text("\(messages.count) total")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Message rows
            ForEach(messages.indices, id: \.self) { index in
                RetroMessageRow(
                    message: messages[index],
                    formatTimeInterval: formatTimeInterval,
                    messageTypeColor: messageTypeColor
                )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.5), RetroTheme.retroBlue.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

#if DEBUG
struct RetroMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            RetroMessagesView(
                messages: [
                    StatusMessage(message: "ROM scanning completed", type: .success),
                    StatusMessage(message: "File access error: Permission denied", type: .error),
                    StatusMessage(message: "Web server started on port 8080", type: .info)
                ],
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

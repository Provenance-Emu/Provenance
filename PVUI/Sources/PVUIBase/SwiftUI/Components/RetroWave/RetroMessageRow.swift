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
    let message: StatusMessage
    let formatTimeInterval: (Date) -> String
    let messageTypeColor: (StatusMessage.MessageType) -> Color
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(messageTypeColor(message.type))
                .frame(width: 8, height: 8)
            
            Text(message.message)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.9))
                .lineLimit(1)
            
            Spacer()
            
            Text(formatTimeInterval(message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.6))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
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

//
//  RetroWebServerStatusView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVWebServer
import PVUIBase

/// A view displaying web server status with retrowave styling
public struct RetroWebServerStatusView: View {
    // MARK: - Properties
    
    /// The web server status
    let status: PVWebServerStatus
    
    /// Callback to start the web server
    let startServer: () -> Void
    
    // MARK: - Initialization
    
    /// Creates a new RetroWebServerStatusView
    /// - Parameters:
    ///   - status: The web server status
    ///   - startServer: Callback to start the web server
    public init(status: PVWebServerStatus, startServer: @escaping () -> Void) {
        self.status = status
        self.startServer = startServer
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 10) {
            // Status indicator with glow effect
            Circle()
                .fill(status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink)
                .frame(width: 10, height: 10)
                .shadow(color: (status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink).opacity(0.7), radius: 3, x: 0, y: 0)
            
            // Status text with retrowave styling
            VStack(alignment: .leading, spacing: 4) {
                Text("WEB SERVER: \(status.isRunning ? "ONLINE" : "OFFLINE")")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink)
                    .shadow(color: (status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink).opacity(0.7), radius: 1, x: 0, y: 0)
                
                if status.isRunning, let address = status.serverAddress {
                    Text(address)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                        .shadow(color: RetroTheme.retroBlue.opacity(0.5), radius: 1, x: 0, y: 0)
                }
            }
            
            Spacer()
            
            // Start button if server is not running
            if !status.isRunning {
                Button(action: startServer) {
                    Text("START")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 2, x: 0, y: 0)
                }
            }
        }
        .padding(12)
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
        .shadow(color: (status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink).opacity(0.5), radius: 3, x: 0, y: 0)
    }
}

#if DEBUG
struct RetroWebServerStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                RetroWebServerStatusView(
                    status: PVWebServerStatus(isRunning: true, serverAddress: "http://192.168.1.100:8080"),
                    startServer: {}
                )
                
                RetroWebServerStatusView(
                    status: PVWebServerStatus(isRunning: false, serverAddress: nil),
                    startServer: {}
                )
            }
            .padding()
        }
    }
}
#endif

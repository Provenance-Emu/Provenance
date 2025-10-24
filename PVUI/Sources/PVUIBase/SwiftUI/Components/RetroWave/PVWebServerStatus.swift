//
//  PVWebServerStatus.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation

/// Represents the status of the PVWebServer
public struct PVWebServerStatus {
    /// Whether the server is currently running
    public let isRunning: Bool
    
    /// The address of the server, if running
    public let serverAddress: String?
    
    /// Creates a new PVWebServerStatus
    /// - Parameters:
    ///   - isRunning: Whether the server is currently running
    ///   - serverAddress: The address of the server, if running
    public init(isRunning: Bool, serverAddress: String?) {
        self.isRunning = isRunning
        self.serverAddress = serverAddress
    }
}

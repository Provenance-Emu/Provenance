//
//  PVAppDelegate+WebServer.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVPrimitives

#if canImport(PVWebServer)
import PVWebServer
import PVUIBase

/// Extension to PVAppDelegate for web server setup
extension PVAppDelegate {
    
    /// Set up web server notifications
    func setupWebServerNotifications() {
        DLOG("""
             Setting up web server notifications to provide real-time
             status updates in the notification system
             """)
        
        // Set up method swizzling to automatically post notifications
        // when web server status changes
        PVWebServer.setupNotifications()
    }
}
#endif

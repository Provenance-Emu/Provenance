//
//  PVWebServerNotifications.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVPrimitives
import PVWebServer

#if canImport(PVWebServer)
import PVWebServer
import ObjectiveC

/// Extension to PVWebServer to post notifications when server status changes
public extension PVWebServer {
  
    /// Setup method swizzling to automatically post notifications
    /// This is called once when the app starts
    static func setupNotifications() {
        // Only set up once
        DispatchQueue.once(token: "PVWebServerNotifications") {
            // Swizzle startServers
            let originalStartSelector = #selector(PVWebServer.startServers)
            let swizzledStartSelector = #selector(PVWebServer.swizzled_startServers)
            
            guard let originalStartMethod = class_getInstanceMethod(PVWebServer.self, originalStartSelector),
                  let swizzledStartMethod = class_getInstanceMethod(PVWebServer.self, swizzledStartSelector) else {
                DLOG("Failed to swizzle startServers method")
                return
            }
            
            method_exchangeImplementations(originalStartMethod, swizzledStartMethod)
            
            // Swizzle stopServers
            let originalStopSelector = #selector(PVWebServer.stopServers)
            let swizzledStopSelector = #selector(PVWebServer.swizzled_stopServers)
            
            guard let originalStopMethod = class_getInstanceMethod(PVWebServer.self, originalStopSelector),
                  let swizzledStopMethod = class_getInstanceMethod(PVWebServer.self, swizzledStopSelector) else {
                DLOG("Failed to swizzle stopServers method")
                return
            }
            
            method_exchangeImplementations(originalStopMethod, swizzledStopMethod)
            
            // Swizzle startWebDavServer
            let originalWebDavSelector = #selector(PVWebServer.startWebDavServer)
            let swizzledWebDavSelector = #selector(PVWebServer.swizzled_startWebDavServer)
            
            guard let originalWebDavMethod = class_getInstanceMethod(PVWebServer.self, originalWebDavSelector),
                  let swizzledWebDavMethod = class_getInstanceMethod(PVWebServer.self, swizzledWebDavSelector) else {
                DLOG("Failed to swizzle startWebDavServer method")
                return
            }
            
            method_exchangeImplementations(originalWebDavMethod, swizzledWebDavMethod)
            
            DLOG("PVWebServer notification methods successfully swizzled")
        }
    }
    
    /// Swizzled implementation of startServers
    @objc func swizzled_startServers() -> Bool {
        // Call the original implementation (which is now this method due to swizzling)
        let result = self.swizzled_startServers()
        
        if result {
            // Post notification for web uploader server
            NotificationCenter.postWebServerStatusChanged(
                isRunning: true,
                port: UInt(80), // Default port for web uploader
                type: .webUploader,
                url: self.url
            )
            
            // Post notification for WebDAV server if it's running
            if self.isWebDavServerRunning {
                NotificationCenter.postWebServerStatusChanged(
                    isRunning: true,
                    port: UInt(81), // Default port for WebDAV
                    type: .webDAV,
                    url: URL(string: self.webDavURLString ?? "")
                )
            }
        }
        
        return result
    }
    
    /// Swizzled implementation of stopServers
    @objc func swizzled_stopServers() {
        // Post notifications before stopping servers
        if self.isWWWUploadServerRunning {
            NotificationCenter.postWebServerStatusChanged(
                isRunning: false,
                port: UInt(80), // Default port for web uploader
                type: .webUploader,
                url: nil
            )
        }
        
        if self.isWebDavServerRunning {
            NotificationCenter.postWebServerStatusChanged(
                isRunning: false,
                port: UInt(81), // Default port for WebDAV
                type: .webDAV,
                url: nil
            )
        }
        
        // Call the original implementation (which is now this method due to swizzling)
        self.swizzled_stopServers()
    }
    
    /// Swizzled implementation of startWebDavServer
    @objc func swizzled_startWebDavServer() -> Bool {
        // Call the original implementation (which is now this method due to swizzling)
        let result = self.swizzled_startWebDavServer()
        
        if result, self.isWebDavServerRunning {
            // Extract the actual port number from the WebDAV URL string
            var port: UInt = 81 // Default fallback
            if let urlString = self.webDavURLString,
               let url = URL(string: urlString),
               let portNumber = url.port {
                port = UInt(portNumber)
            }
            
            NotificationCenter.postWebServerStatusChanged(
                isRunning: true,
                port: port,
                type: .webDAV,
                url: URL(string: self.webDavURLString ?? "")
            )
        }
        
        return result
    }
}
#endif

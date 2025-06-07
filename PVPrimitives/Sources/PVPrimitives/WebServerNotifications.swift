//
//  WebServerNotifications.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation

/// Extension to provide notification posting for web server status changes
public extension NotificationCenter {
    /// Post a notification when the web server status changes
    /// - Parameters:
    ///   - isRunning: Whether the server is running
    ///   - port: The port the server is running on
    ///   - type: The type of server (WebUploader or WebDAV)
    ///   - url: The URL of the server
    static func postWebServerStatusChanged(isRunning: Bool, port: UInt, type: WebServerType, url: URL?) {
        let userInfo: [String: Any] = [
            "isRunning": isRunning,
            "port": port,
            "type": type.rawValue,
            "url": url as Any
        ]
        
        NotificationCenter.default.post(
            name: .webServerStatusChanged,
            object: nil,
            userInfo: userInfo
        )
    }
}

/// The type of web server
public enum WebServerType: String {
    case webUploader = "WebUploader"
    case webDAV = "WebDAV"
}

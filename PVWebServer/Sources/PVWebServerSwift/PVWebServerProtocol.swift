//
//  PVWebServerProtocol.swift
//  PVWebServer
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Unified protocol that both the legacy GCDWebServer adapter and the new
//  Hummingbird-based server conform to.  PVWebServerManager selects the
//  active implementation at runtime via the `modernWebServer` feature flag.
//

import Foundation
import PVPrimitives

// MARK: - Notification names (kept identical to legacy PVWebServer.m constants)

public extension Notification.Name {
    /// Fired when a file upload begins (userInfo: "path": String)
    static let pvWebServerFileUploadStarted    = Notification.Name("PVWebServerFileUploadStartedNotification")
    /// Fired periodically during an upload (userInfo: progress keys)
    static let pvWebServerFileUploadProgress   = Notification.Name("PVWebServerFileUploadProgressNotification")
    /// Fired when a file upload finishes successfully (userInfo: "filePath", "fileSize")
    static let pvWebServerFileUploadCompleted  = Notification.Name("PVWebServerFileUploadCompletedNotification")
    /// Fired when a file upload fails (userInfo: "filePath", "error")
    static let pvWebServerFileUploadFailed     = Notification.Name("PVWebServerFileUploadFailedNotification")
    /// Fired with upload progress for status-bar UI (userInfo: progress keys)
    static let pvWebServerUploadProgress       = Notification.Name("WebServerUploadProgress")
    /// Fired when an upload finishes for status-bar UI
    static let pvWebServerUploadCompleted      = Notification.Name("WebServerUploadCompleted")
    /// Fired when server start/stop state changes (userInfo: "isRunning", "type", "port", "url")
    static let pvWebServerStatusChanged        = Notification.Name("WebServerStatusChanged")

    // MARK: File-lifecycle events (Task B — Epic #2758)
    // Canonical definitions live in PVPrimitives/StatusNotifications.swift so both
    // PVWebServer (this module) and PVLibrary can reference the same typed constants
    // without a cross-tier dependency between those two modules.
    // Access them via `import PVPrimitives`:
    //   Notification.Name.pvWebServerFileDeleted
    //   Notification.Name.pvWebServerFileMoved
}

// MARK: - PVWebServerProtocol

/// Abstracts over the legacy GCDWebServer and the modern Hummingbird server.
/// Both servers must fire the Notification.Name constants above on the same
/// events so the rest of the app remains unaffected by which server is active.
public protocol PVWebServerProtocol: AnyObject, Sendable {

    // MARK: State

    var isWWWServerRunning: Bool { get }
    var isWebDAVServerRunning: Bool { get }

    /// Local HTTP URL for the file-uploader UI (e.g. `http://192.168.1.5/`)
    var serverURL: URL? { get }

    /// Local WebDAV URL (e.g. `http://192.168.1.5:8081/`)
    var webDAVURL: URL? { get }

    // MARK: Lifecycle

    /// Start both the HTTP file-upload server and the WebDAV server.
    /// - Returns: `true` if both servers started successfully.
    @discardableResult
    func startServers() async throws -> Bool

    /// Stop both servers.
    func stopServers() async
}

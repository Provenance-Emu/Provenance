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
    /// Fired when a file is deleted via the web UI or WebDAV.
    /// userInfo: `"filePath": String` — absolute path of the deleted file.
    static let pvWebServerFileDeleted = Notification.Name("PVWebServerFileDeletedNotification")
    /// Fired when a file is moved/renamed via the web UI or WebDAV.
    /// userInfo: `"fromPath": String, "toPath": String`
    static let pvWebServerFileMoved   = Notification.Name("PVWebServerFileMovedNotification")
}

// MARK: - Ports

/// Single source of truth for which ports the web servers bind on this device.
///
/// iOS lets any process bind low ports, so on real hardware we use the pretty
/// `80`/`81` pair and the URL is just `http://<ip>/`. Simulator and macOS both
/// inherit the BSD rule that ports below 1024 are root-only, so they need the
/// high pair.
///
/// The shipping Mac build is the **iOS binary running as "Designed for iPad"**,
/// not Mac Catalyst — `targetEnvironment(macCatalyst)` is false there, so the
/// old compile-time Catalyst check never fired and the Mac tried to bind 80/81
/// and failed. `ProcessInfo.isiOSAppOnMac` is the only runtime hook that sees it.
public enum PVWebServerPorts {

    /// HTTP file-uploader port used where low ports are unavailable.
    public static let desktopUpload = 8080
    /// WebDAV port used where low ports are unavailable.
    public static let desktopWebDAV = 8081
    /// HTTP file-uploader port used on iOS/tvOS hardware.
    public static let deviceUpload = 80
    /// WebDAV port used on iOS/tvOS hardware.
    public static let deviceWebDAV = 81

    /// `true` when the host reserves ports below 1024 for root.
    public static var usesHighPorts: Bool {
#if targetEnvironment(simulator) || os(macOS) || targetEnvironment(macCatalyst)
        return true
#else
        return ProcessInfo.processInfo.isiOSAppOnMac
#endif
    }

    /// HTTP file-uploader port for this device.
    public static var upload: Int { usesHighPorts ? desktopUpload : deviceUpload }
    /// WebDAV port for this device.
    public static var webDAV: Int { usesHighPorts ? desktopWebDAV : deviceWebDAV }

    /// Comma-separated port list for user-facing "couldn't start" copy.
    public static var userFacingList: String { "\(upload), \(webDAV)" }
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

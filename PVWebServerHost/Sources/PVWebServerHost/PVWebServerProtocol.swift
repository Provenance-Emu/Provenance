//
//  PVWebServerProtocol.swift
//  PVWebServerHost
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  HTTP/WebDAV lifecycle and stable notification contracts.
//

import Foundation

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
    /// Fired when a folder is created via the web UI or WebDAV.
    /// userInfo: `"filePath": String` — absolute path of the new folder.
    static let pvWebServerFolderCreated = Notification.Name("PVWebServerFolderCreatedNotification")
}

// MARK: - Ports

/// Single source of truth for which ports the web server tries on this device. HTTP and
/// WebDAV share one listener, so there is one port.
///
/// iOS lets any process bind low ports, so on real hardware the first choice is `80` and the
/// URL is just `http://<ip>/`. Simulator and macOS both inherit the BSD rule that ports below
/// 1024 are root-only, so they start from the high port.
///
/// The shipping Mac build is the **iOS binary running as "Designed for iPad"**, not Mac
/// Catalyst — `targetEnvironment(macCatalyst)` is false there, so a compile-time check never
/// fires. `ProcessInfo.isiOSAppOnMac` is the only runtime hook that sees it.
///
/// The first choice is a preference, not a promise. iFly and iCube run their own servers on
/// the same device; whoever binds a port first owns it and the loser gets `EADDRINUSE`. Each
/// app has its own home port (`ecosystemHomePorts`), and the listener keeps the first port it
/// actually binds. Everything user-facing reads that bound port
/// (`PVHostedWebServer.boundPort`), never these constants.
public enum PVWebServerPorts {

    /// Port used where low ports are unavailable.
    public static let desktopUpload = 8080
    /// Port used on iOS/tvOS hardware.
    public static let deviceUpload = 80

    /// Home ports of every app that can share the device (Joe's port map, 2026-11-08).
    /// No fallback list may land on another app's home port, or the apps would take
    /// each other's ports whenever one starts before the other.
    ///
    /// | App | Home | Fallback |
    /// |---|---|---|
    /// | Provenance (HTTP + WebDAV, one listener) | 80 on device, 8080 on sim and Mac | 8180–8189 |
    /// | Provenance library sharing | 8484 and up (one listener per dialect) | through 8515 |
    /// | iFly (HTTP + WebDAV, one listener) | 8090 | 8092–8099 |
    /// | iCube (HTTP + WebDAV, one listener) | 8091 | 8190–8199 |
    public static let ecosystemHomePorts: Set<Int> = Set([80, 8080, 8090, 8091]).union(8484...8515)

    /// Provenance's fallback range.
    public static let fallbackRange = 8180...8189

    /// Order on hardware: home port, then `fallbackRange`.
    public static let deviceCandidates = [deviceUpload] + fallbackRange
    /// Order where low ports are root-only.
    public static let desktopCandidates = [desktopUpload] + fallbackRange

    /// `true` when the host reserves ports below 1024 for root.
    public static var usesHighPorts: Bool {
#if targetEnvironment(simulator) || os(macOS) || targetEnvironment(macCatalyst)
        return true
#else
        return ProcessInfo.processInfo.isiOSAppOnMac
#endif
    }

    /// Preferred port for this device (first candidate).
    public static var upload: Int { usesHighPorts ? desktopUpload : deviceUpload }

    /// Ports to try, in order, on this device.
    public static var candidates: [Int] { usesHighPorts ? desktopCandidates : deviceCandidates }

    /// Every port tried, comma-separated, for user-facing "couldn't start" copy.
    /// When the server is up, show `PVWebServerManager.httpPort` instead.
    public static var userFacingList: String {
        candidates.map(String.init).joined(separator: ", ")
    }
}

// MARK: - PVWebServerProtocol

/// HTTP/WebDAV lifecycle contract. Implementations emit the notification names
/// above so upload, file event and status observers stay independent of presentation.
public protocol PVWebServerProtocol: AnyObject, Sendable {

    // MARK: State

    var isRunning: Bool { get }

    /// Local URL for the file-manager page and for WebDAV (e.g. `http://192.168.1.5/`)
    var serverURL: URL? { get }

    /// The port the listener actually holds, or `nil` while it is down.
    var boundPort: Int? { get }

    /// Called (once per start) when the listener stops without `stopServers()`,
    /// e.g. iOS defuncting the socket while the app was suspended. The server has
    /// already marked itself down and withdrawn its Bonjour records.
    func setUnexpectedStopHandler(_ handler: @escaping @Sendable () -> Void)

    // MARK: Lifecycle

    /// Start the HTTP and WebDAV service.
    /// - Returns: `true` if it started.
    @discardableResult
    func startServers() async throws -> Bool

    /// Stop the service.
    func stopServers() async
}

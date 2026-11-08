//
//  PVWebServerProtocol.swift
//  PVWebServer
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
}

// MARK: - Ports

/// Single source of truth for which ports the web servers try on this device.
///
/// iOS lets any process bind low ports, so on real hardware the first choice is
/// the pretty `80`/`81` pair and the URL is just `http://<ip>/`. Simulator and
/// macOS both inherit the BSD rule that ports below 1024 are root-only, so they
/// start from the high pair.
///
/// The shipping Mac build is the **iOS binary running as "Designed for iPad"**,
/// not Mac Catalyst — `targetEnvironment(macCatalyst)` is false there, so the
/// old compile-time Catalyst check never fired and the Mac tried to bind 80/81
/// and failed. `ProcessInfo.isiOSAppOnMac` is the only runtime hook that sees it.
///
/// The first choice is a preference, not a promise. iFly and iCube want port 80
/// on the same device and whoever binds first owns it; the loser gets
/// `EADDRINUSE`. So each listener walks its candidate list and keeps the first
/// port it actually binds, and everything user-facing reads that bound port
/// (`PVModernWebServer.boundHTTPPort` / `boundWebDAVPort`), never these constants.
public enum PVWebServerPorts {

    /// HTTP file-uploader port used where low ports are unavailable.
    public static let desktopUpload = 8080
    /// WebDAV port used where low ports are unavailable.
    public static let desktopWebDAV = 8081
    /// HTTP file-uploader port used on iOS/tvOS hardware.
    public static let deviceUpload = 80
    /// WebDAV port used on iOS/tvOS hardware.
    public static let deviceWebDAV = 81

    /// HTTP fallback order on hardware. Same list as iFly's and iCube's servers.
    public static let deviceUploadCandidates = [deviceUpload, 8080, 8000, 8888, 9000]
    /// WebDAV fallback order on hardware. Disjoint from the HTTP list so the two never compete.
    public static let deviceWebDAVCandidates = [deviceWebDAV, 8081, 8001, 8889, 9001]
    /// HTTP fallback order where low ports are root-only.
    public static let desktopUploadCandidates = [desktopUpload, 8000, 8888, 9000]
    /// WebDAV fallback order where low ports are root-only.
    public static let desktopWebDAVCandidates = [desktopWebDAV, 8001, 8889, 9001]

    /// `true` when the host reserves ports below 1024 for root.
    public static var usesHighPorts: Bool {
#if targetEnvironment(simulator) || os(macOS) || targetEnvironment(macCatalyst)
        return true
#else
        return ProcessInfo.processInfo.isiOSAppOnMac
#endif
    }

    /// Preferred HTTP file-uploader port for this device (first candidate).
    public static var upload: Int { usesHighPorts ? desktopUpload : deviceUpload }
    /// Preferred WebDAV port for this device (first candidate).
    public static var webDAV: Int { usesHighPorts ? desktopWebDAV : deviceWebDAV }

    /// HTTP ports to try, in order, on this device.
    public static var uploadCandidates: [Int] { usesHighPorts ? desktopUploadCandidates : deviceUploadCandidates }
    /// WebDAV ports to try, in order, on this device.
    public static var webDAVCandidates: [Int] { usesHighPorts ? desktopWebDAVCandidates : deviceWebDAVCandidates }

    /// Every port tried, comma-separated, for user-facing "couldn't start" copy.
    /// When the server is up, show `PVWebServerManager.httpPort` / `webDAVPort` instead.
    public static var userFacingList: String {
        (uploadCandidates + webDAVCandidates).map(String.init).joined(separator: ", ")
    }

    /// `candidates` in order, without duplicates, invalid ports or anything in `excluded`.
    /// WebDAV passes the HTTP listener's bound port as `excluded` so the two stay distinct.
    public static func bindOrder(_ candidates: [Int], excluding excluded: Set<Int> = []) -> [Int] {
        var seen = excluded
        return candidates.filter { (1...65_535).contains($0) && seen.insert($0).inserted }
    }

    /// Tries `candidates` in order and returns the first port `attempt` binds, or `nil`.
    /// `attempt` returns `false` (or throws) when the port is taken; the next one is tried.
    public static func firstBound(
        _ candidates: [Int],
        excluding excluded: Set<Int> = [],
        attempt: (Int) async throws -> Bool
    ) async -> Int? {
        for port in bindOrder(candidates, excluding: excluded) {
            if (try? await attempt(port)) == true { return port }
        }
        return nil
    }
}

// MARK: - PVWebServerProtocol

/// HTTP/WebDAV lifecycle contract. Implementations emit the notification names
/// above so upload, file event and status observers stay independent of presentation.
public protocol PVWebServerProtocol: AnyObject, Sendable {

    // MARK: State

    var isWWWServerRunning: Bool { get }
    var isWebDAVServerRunning: Bool { get }

    /// Local HTTP URL for the file-uploader UI (e.g. `http://192.168.1.5/`)
    var serverURL: URL? { get }

    /// Local WebDAV URL (e.g. `http://192.168.1.5:8081/`)
    var webDAVURL: URL? { get }

    /// The port the HTTP listener actually holds, or `nil` while it is down.
    var boundHTTPPort: Int? { get }

    /// The port the WebDAV listener actually holds, or `nil` while it is down.
    var boundWebDAVPort: Int? { get }

    /// Called (once per start) when a confirmed listener stops without `stopServers()`,
    /// e.g. iOS defuncting the socket while the app was suspended. The server has
    /// already marked itself down and withdrawn its Bonjour records.
    func setUnexpectedStopHandler(_ handler: @escaping @Sendable () -> Void)

    // MARK: Lifecycle

    /// Start both the HTTP file-upload server and the WebDAV server.
    /// - Returns: `true` if both servers started successfully.
    @discardableResult
    func startServers() async throws -> Bool

    /// Stop both servers.
    func stopServers() async
}

public extension PVWebServerProtocol {
    var boundHTTPPort: Int? { nil }
    var boundWebDAVPort: Int? { nil }
    func setUnexpectedStopHandler(_ handler: @escaping @Sendable () -> Void) {}
}

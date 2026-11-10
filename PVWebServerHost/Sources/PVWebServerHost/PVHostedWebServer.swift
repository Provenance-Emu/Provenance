//
//  PVHostedWebServer.swift
//  PVWebServerHost
//
//  Provenance's web server: the shared PVWebServer engine (HTTP and WebDAV on one port),
//  serving the app's documents, with Provenance's file-manager page and debug API on top.
//  Owned by `PVWebServerManager`, one instance per start.
//

import Foundation
import PVLogging
import PVWebServer
#if canImport(UIKit)
import UIKit
#endif

public final class PVHostedWebServer: @unchecked Sendable {

    /// Default destination for `POST /upload` without a `path` query. Defaults to
    /// `<browseRoot>/Imports`.
    public let uploadDirectory: URL
    /// What the server exposes. Client paths resolve against it and may not leave it.
    /// Documents on iOS and macOS, Caches on tvOS (where Documents is unwritable).
    public let browseRoot: URL

    let engine: PVWebServer
    let events = WebEventHub()
    /// Stamped on init so `/stats` can report uptime to the dashboard.
    let startedAt = Date()

    private let lock = NSLock()
    private var unexpectedStopHandler: (@Sendable () -> Void)?
    private var fileEventObservers: [NSObjectProtocol] = []

    /// - Parameter ports: tried in order until one binds. Default: `PVWebServerPorts.candidates`.
    public convenience init(uploadDirectory: URL? = nil, browseRoot: URL? = nil, ports: [Int]? = nil) {
        self.init(uploadDirectory: uploadDirectory, browseRoot: browseRoot, ports: ports, debugAPI: .fromPreferences())
    }

    /// - Parameter debugAPI: `nil` leaves `/api/debug` unmounted.
    init(uploadDirectory: URL?, browseRoot: URL?, ports: [Int]?, debugAPI: DebugAPIAccess?) {
        let root = browseRoot ?? Self.defaultBrowseRoot()
        let uploads = uploadDirectory ?? root.appendingPathComponent("Imports")
        self.browseRoot = root
        self.uploadDirectory = uploads
        self.engine = PVWebServer(configuration: WebServerConfiguration(
            rootDirectory: root,
            defaultUploadDirectory: uploads,
            pageTitle: "Provenance",
            bonjourName: "Provenance",
            preferredPorts: ports ?? PVWebServerPorts.candidates,
            reportsWebDAVMovesAsUploads: false
        ))
        try? FileManager.default.createDirectory(at: uploads, withIntermediateDirectories: true)

        registerFileRoutes()
        registerDashboardRoutes()
        if let debugAPI { mountDebugAPI(debugAPI) }
    }

    private static func defaultBrowseRoot() -> URL {
        #if os(tvOS)
        let directory = FileManager.SearchPathDirectory.cachesDirectory
        #else
        let directory = FileManager.SearchPathDirectory.documentDirectory
        #endif
        return FileManager.default.urls(for: directory, in: .userDomainMask)[0]
    }
}

// MARK: - PVWebServerProtocol

extension PVHostedWebServer: PVWebServerProtocol {

    public var isRunning: Bool { engine.isRunning }

    public var boundPort: Int? { engine.isRunning ? engine.port : nil }

    public var serverURL: URL? {
        guard let port = boundPort, let ip = engine.ipAddress else { return nil }
        return URL(string: "http://\(ip)\(port == 80 ? "" : ":\(port)")/")
    }

    public func setUnexpectedStopHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.withLock { unexpectedStopHandler = handler }
    }

    @discardableResult
    public func startServers() async throws -> Bool {
        observeFileEvents()
        engine.setUnexpectedStopHandler { [weak self] in self?.listenerDied() }
        do {
            try await engine.start()
        } catch {
            stopObservingFileEvents()
            WLOG("[PVHostedWebServer] no port bound: \(error.localizedDescription). Tried \(PVWebServerPorts.userFacingList).")
            return false
        }
        postStatus(isRunning: true, port: boundPort ?? PVWebServerPorts.upload, url: serverURL)
        setIdleTimerDisabled(true)
        return true
    }

    public func stopServers() async {
        let port = boundPort
        engine.stopServers()
        wentDown(port: port)
    }

    /// iOS closes the sockets of suspended apps, and another app may hold the port by now.
    /// The engine has already stopped itself and withdrawn its Bonjour records.
    private func listenerDied() {
        ELOG("[PVHostedWebServer] listener stopped unexpectedly")
        wentDown(port: nil)
        let handler = lock.withLock {
            defer { unexpectedStopHandler = nil }
            return unexpectedStopHandler
        }
        handler?()
    }

    private func wentDown(port: Int?) {
        stopObservingFileEvents()
        events.finishAll()
        postStatus(isRunning: false, port: port ?? PVWebServerPorts.upload, url: nil)
        setIdleTimerDisabled(false)
    }

    /// Observers filter on `type`, and WebDAV shares the upload port, so each change is
    /// reported for both.
    private func postStatus(isRunning: Bool, port: Int, url: URL?) {
        for type in ["WebUploader", "WebDAV"] {
            var info: [String: Any] = ["isRunning": isRunning, "type": type, "port": port]
            if let url { info["url"] = url.absoluteString }
            NotificationCenter.default.post(name: .pvWebServerStatusChanged, object: self, userInfo: info)
        }
    }

    private func setIdleTimerDisabled(_ disabled: Bool) {
        #if canImport(UIKit) && !os(watchOS)
        // Not `MainActor.run`: a @MainActor caller awaiting `PVWebServerManager.start()` would
        // wait on this while this waits on it.
        DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = disabled }
        #endif
    }
}

// MARK: - File events

private extension PVHostedWebServer {

    /// Feeds connected browsers from the same notifications the library observes, so a change
    /// made over WebDAV shows up on an open page like one made on the page itself.
    func observeFileEvents() {
        let center = NotificationCenter.default
        let observe: (Notification.Name, @escaping (PVHostedWebServer, [AnyHashable: Any]) -> Void) -> NSObjectProtocol = { name, body in
            center.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                guard let self else { return }
                body(self, note.userInfo ?? [:])
            }
        }
        let observers = [
            observe(.pvWebServerFileUploadCompleted) { server, info in
                guard let path = info["filePath"] as? String else { return }
                server.broadcast(type: "upload", path: path)
                // The status bar reads this size as Int64; the engine reports UInt64.
                let size = (info["fileSize"] as? NSNumber)?.int64Value ?? 0
                center.post(
                    name: .pvWebServerUploadCompleted,
                    object: server,
                    userInfo: ["fileName": path, "fileSize": size]
                )
            },
            observe(.pvWebServerFileDeleted) { server, info in
                guard let path = info["filePath"] as? String else { return }
                server.broadcast(type: "delete", path: path)
            },
            observe(.pvWebServerFolderCreated) { server, info in
                guard let path = info["filePath"] as? String else { return }
                server.broadcast(type: "folder", path: path)
            },
            observe(.pvWebServerFileMoved) { server, info in
                guard let from = info["fromPath"] as? String, let to = info["toPath"] as? String else { return }
                server.broadcast(type: "rename", path: to, extra: ["from": server.relativeBrowsePath(for: from)])
            }
        ]
        lock.withLock { fileEventObservers = observers }
    }

    func stopObservingFileEvents() {
        let observers = lock.withLock {
            defer { fileEventObservers = [] }
            return fileEventObservers
        }
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}

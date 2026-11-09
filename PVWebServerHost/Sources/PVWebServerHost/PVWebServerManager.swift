//
//  PVWebServerManager.swift
//  PVWebServerHost
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Owns the HTTP/WebDAV server independently of presented controls.
//
//  Usage:
//    let ok = try await PVWebServerManager.shared.start()
//    await PVWebServerManager.shared.stop()
//

import Combine
import Foundation
import PVLogging

// MARK: - PVWebServerManager

/// Unified async/await entry point for starting and stopping the web server.
public actor PVWebServerManager {

    // MARK: Singleton

    public static let shared = PVWebServerManager()

    // MARK: State

    private var activeServer: (any PVWebServerProtocol)?
    // Actor methods can interleave at await. Chain lifecycle operations so a second
    // presentation cannot restart a pending listener or race an explicit Stop.
    private var lifecycleOperation: Task<Void, Never>?
    private let serverFactory: @Sendable () -> any PVWebServerProtocol

    // MARK: Init

    public init() {
        serverFactory = { PVHostedWebServer() }
    }

    /// Internal dependency boundary for lifecycle tests without binding device ports.
    init(serverFactory: @escaping @Sendable () -> any PVWebServerProtocol) {
        self.serverFactory = serverFactory
    }

    // MARK: - Public API

    /// Returns whether the server is currently running.
    public var isRunning: Bool { activeServer?.isRunning == true }

    /// Diagnostic description of the impl that will be / has been started.
    /// Read from `WebServerBootstrapTask` so the log shows which backend is
    /// in play even when `start()` later fails silently.
    public var implementationDescription: String {
        "PVWebServer (Network.framework)"
    }

    /// Local HTTP file-uploader URL, if the server is running.
    public var serverURL: URL? { activeServer?.serverURL }

    /// Local WebDAV URL, if the server is running. WebDAV shares the HTTP port.
    public var webDAVURL: URL? { activeServer?.serverURL }

    /// The HTTP port actually bound, while running. Not `serverURL?.port`: that is `nil`
    /// for `http://ip/`, which means port 80. Port 80 is only a preference, so this can be a
    /// fallback port.
    public var httpPort: Int? { isRunning ? activeServer?.boundPort : nil }

    /// Start the HTTP and WebDAV service.
    /// - Returns: `true` if it started.
    /// - Throws: Any error propagated from the server.
    @discardableResult
    public func start() async throws -> Bool {
        let previous = lifecycleOperation
        let operation = Task {
            await previous?.value
            return try await startIfNeeded()
        }
        lifecycleOperation = Task { _ = try? await operation.value }
        return try await operation.value
    }

    /// Explicitly stop services. Dismissing a presentation never calls this.
    public func stop() async {
        let previous = lifecycleOperation
        let operation = Task {
            await previous?.value
            await stopIfNeeded()
        }
        lifecycleOperation = operation
        await operation.value
    }

    private func startIfNeeded() async throws -> Bool {
        if let existing = activeServer {
            guard !isRunning else { return true }
            await existing.stopServers()
            activeServer = nil
        }
        let server = serverFactory()
        do {
            let ok = try await server.startServers()
            if ok {
                activeServer = server
                let id = ObjectIdentifier(server)
                server.setUnexpectedStopHandler { [weak self] in
                    Task { await self?.restartAfterUnexpectedStop(of: id) }
                }
                ILOG("[WebServerManager] Started server at \(server.serverURL?.absoluteString ?? "?")")
            } else {
                // Tear down a partial start so a subsequent attempt can bind cleanly.
                await server.stopServers()
                WLOG("[WebServerManager] startServers returned false; implementation was stopped to reset state.")
            }
            return ok
        } catch {
            await server.stopServers()
            ELOG("[WebServerManager] startServers threw: \(error.localizedDescription)")
            throw error
        }
    }

    /// The listener died without `stop()` (iOS defuncts sockets of suspended apps). The server
    /// already withdrew its adverts; bind again, possibly on another port if an app took
    /// ours meanwhile. Runs in the lifecycle chain, so an explicit `stop()` queued first wins.
    private func restartAfterUnexpectedStop(of id: ObjectIdentifier) async {
        let previous = lifecycleOperation
        let operation = Task {
            await previous?.value
            guard let active = activeServer, ObjectIdentifier(active) == id else { return }
            WLOG("[WebServerManager] Listener stopped unexpectedly; restarting")
            do {
                _ = try await startIfNeeded()
            } catch {
                ELOG("[WebServerManager] Restart after unexpected stop failed: \(error.localizedDescription)")
            }
        }
        lifecycleOperation = operation
        await operation.value
    }

    private func stopIfNeeded() async {
        guard let server = activeServer else { return }
        await server.stopServers()
        activeServer = nil
        ILOG("[WebServerManager] Stopped web server")
    }

}

// MARK: - Combine publishers for file-lifecycle events (Task B — Epic #2758)

extension PVWebServerManager {

    /// Emits the absolute path of every file deleted via the web UI or WebDAV.
    /// Uses the stable `pvWebServerFileDeleted` notification contract.
    public nonisolated var fileDeletedPublisher: AnyPublisher<String, Never> {
        NotificationCenter.default
            .publisher(for: .pvWebServerFileDeleted)
            .compactMap { $0.userInfo?["filePath"] as? String }
            .eraseToAnyPublisher()
    }

    /// Emits `(fromPath, toPath)` tuples for every file moved/renamed via the web UI or WebDAV.
    public nonisolated var fileMovedPublisher: AnyPublisher<(from: String, to: String), Never> {
        NotificationCenter.default
            .publisher(for: .pvWebServerFileMoved)
            .compactMap { note -> (from: String, to: String)? in
                guard
                    let from = note.userInfo?["fromPath"] as? String,
                    let to   = note.userInfo?["toPath"]   as? String
                else { return nil }
                return (from: from, to: to)
            }
            .eraseToAnyPublisher()
    }
}

//
//  PVWebServerManager.swift
//  PVWebServer
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Owns the Swift HTTP/WebDAV server independently of presented controls.
//
//  Usage:
//    let ok = try await PVWebServerManager.shared.start()
//    await PVWebServerManager.shared.stop()
//

import Combine
import Foundation
import PVLogging

// MARK: - PVWebServerManager

/// Unified async/await entry point for starting and stopping the web servers.
/// Uses the Swift-native Hummingbird backend for fresh installs and upgrades.
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
        serverFactory = { PVModernWebServer() }
    }

    /// Internal dependency boundary for lifecycle tests without binding device ports.
    init(serverFactory: @escaping @Sendable () -> any PVWebServerProtocol) {
        self.serverFactory = serverFactory
    }

    // MARK: - Public API

    /// Returns whether either server is currently running.
    public var isRunning: Bool {
        activeServer?.isWWWServerRunning == true && activeServer?.isWebDAVServerRunning == true
    }

    /// Diagnostic description of the impl that will be / has been started.
    /// Read from `WebServerBootstrapTask` so the log shows which backend is
    /// in play even when `start()` later fails silently.
    public var implementationDescription: String {
        "Modern (Hummingbird)"
    }

    /// Local HTTP file-uploader URL, if the server is running.
    public var serverURL: URL? { activeServer?.serverURL }

    /// Local WebDAV URL, if the server is running.
    public var webDAVURL: URL? { activeServer?.webDAVURL }

    /// Start both HTTP and WebDAV services.
    /// - Returns: `true` if both services started successfully.
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
                ILOG("[WebServerManager] Started Swift server — HTTP: \(server.serverURL?.absoluteString ?? "?"), DAV: \(server.webDAVURL?.absoluteString ?? "?")")
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

//
//  PVWebServerManager.swift
//  PVWebServer
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Feature-flagged actor that owns the active web server implementation.
//  Uses `PVModernWebServer` (Hummingbird) when the `modernWebServer` flag is
//  enabled; falls back to the legacy ObjC `PVWebServer` via
//  `PVLegacyWebServerAdapter` when the flag is off.
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
/// Internally delegates to either `PVModernWebServer` or `PVLegacyWebServerAdapter`
/// based on the `modernWebServer` feature flag.
public actor PVWebServerManager {

    // MARK: Singleton

    public static let shared = PVWebServerManager()

    // MARK: State

    private var activeServer: (any PVWebServerProtocol)?
    var useModernServer: Bool

    // MARK: Init

    /// Designated initialiser. `useModernServer` can be injected for tests;
    /// production callers use the `shared` singleton which reads the feature flag.
    public init(useModernServer: Bool? = nil) {
        if let override = useModernServer {
            self.useModernServer = override
        } else {
            // Read from UserDefaults debug overrides (synchronous on init).
            // Full feature-flag evaluation happens at start() time.
            self.useModernServer = false
        }
    }

    // MARK: - Public API

    /// Returns whether either server is currently running.
    public var isRunning: Bool { activeServer != nil }

    /// Local HTTP file-uploader URL, if the server is running.
    public var serverURL: URL? { activeServer?.serverURL }

    /// Local WebDAV URL, if the server is running.
    public var webDAVURL: URL? { activeServer?.webDAVURL }

    /// Start both the HTTP and WebDAV servers using the current `useModernServer` value.
    ///
    /// Call `refreshFeatureFlag()` before `start()` if you need to re-evaluate the
    /// `modernWebServer` flag from `UserDefaults` debug overrides or `features.json`.
    ///
    /// - Returns: `true` if both servers started successfully.
    /// - Throws: Any error propagated from the active server implementation.
    @discardableResult
    public func start() async throws -> Bool {
        // Stop any existing server first.
        // Clear activeServer BEFORE awaiting stopServers() to avoid actor re-entrancy
        // issues where a concurrent call to start() could observe the stale reference.
        if let existing = activeServer {
            activeServer = nil
            await existing.stopServers()
        }

        let server = await makeServer()
        let ok = try await server.startServers()
        if ok {
            activeServer = server
            let implName = useModernServer ? "Modern (Hummingbird)" : "Legacy (GCDWebServer)"
            ILOG("[WebServerManager] Started \(implName) server — HTTP: \(server.serverURL?.absoluteString ?? "?"), DAV: \(server.webDAVURL?.absoluteString ?? "?")")
        }
        return ok
    }

    /// Stop the active server (if any).
    public func stop() async {
        guard let server = activeServer else { return }
        await server.stopServers()
        activeServer = nil
        ILOG("[WebServerManager] Stopped web server")
    }

    // MARK: - Private

    /// Creates the active server implementation.
    ///
    /// `PVLegacyWebServerAdapter` wraps the ObjC `PVWebServer` singleton whose
    /// `+initialize` method (`GCDWebServerInitializeFunctions`) asserts it is called
    /// on the main thread.  Bounce through `MainActor.run` so the first ObjC class
    /// initialisation always happens on the main thread regardless of which actor
    /// or queue this method is called from.
    private func makeServer() async -> any PVWebServerProtocol {
        if useModernServer {
            return PVModernWebServer()
        } else {
            return await MainActor.run { PVLegacyWebServerAdapter() }
        }
    }
}

// MARK: - Combine publishers for file-lifecycle events (Task B — Epic #2758)

extension PVWebServerManager {

    /// Emits the absolute path of every file deleted via the web UI or WebDAV.
    /// Works with both the legacy and the modern server — they both post the same
    /// `pvWebServerFileDeleted` notification to `NotificationCenter`.
    public nonisolated var fileDeletedPublisher: AnyPublisher<String, Never> {
        NotificationCenter.default
            .publisher(for: .pvWebServerFileDeleted)
            .compactMap { $0.userInfo?["filePath"] as? String }
            .eraseToAnyPublisher()
    }

    /// Emits `(fromPath, toPath)` tuples for every file moved/renamed via WebDAV.
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

// MARK: - Feature Flag Evaluation

extension PVWebServerManager {

    /// Call this once at app startup (or when feature flags are refreshed) to
    /// pick up the current `modernWebServer` flag value.  Safe to call from any
    /// isolation context — the actor serialises the write.
    public func refreshFeatureFlag() {
        // Check UserDefaults debug override first (mirrors PVFeatureFlags logic).
        if let rawDict = UserDefaults.standard.dictionary(forKey: "PVFeatureFlagsDebugOverrides"),
           let override = rawDict["modernWebServer"] as? Bool {
            useModernServer = override
            return
        }

        // No debug override present — default to the legacy ObjC web server.
        // NOTE: This does NOT currently read from PVFeatureFlags/features.json.
        // Callers with a resolved PVFeatureFlagsManager should inject the value explicitly:
        //   await PVWebServerManager.shared.setModernServerEnabled(flags.modernWebServer)
        useModernServer = false
    }

    /// Programmatically override the implementation selection (useful for tests
    /// or for callers that already have a resolved `PVFeatureFlagsManager`).
    public func setModernServerEnabled(_ enabled: Bool) {
        useModernServer = enabled
    }
}

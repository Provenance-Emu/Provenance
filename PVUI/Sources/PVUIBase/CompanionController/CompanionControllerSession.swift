// CompanionControllerSession.swift
// PVUI
//
// ObservableObject that manages the lifecycle of a companion controller session:
// pairing, connection state, DSU slot assignment, and teardown.
//
// The session is the single source of truth for the companion UI. Bind the
// SwiftUI host view to this object and observe `connectionState`.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation
import Combine
import Network

// MARK: - CompanionConnectionState

/// All possible states of a companion controller session.
public enum CompanionConnectionState: Equatable, Sendable {
    /// Not yet paired. The UI should show a QR code or IP-entry form.
    case disconnected

    /// Attempting to reach the DSU host.
    case connecting(host: String, port: UInt16)

    /// Successfully paired; the layout overlay should be shown.
    case connected(host: String, slotIndex: Int)

    /// A recoverable or fatal error occurred.
    case error(reason: String)

    // MARK: - Convenience

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }

    public var errorReason: String? {
        if case .error(let reason) = self { return reason }
        return nil
    }
}

// MARK: - CompanionControllerSession

/// Manages a companion controller session end-to-end.
///
/// Usage:
/// ```swift
/// @StateObject var session = CompanionControllerSession()
///
/// // To connect:
/// session.connect(host: "192.168.1.5", port: 26760)
///
/// // To disconnect:
/// session.disconnect()
/// ```
///
/// DSU integration (PVControllerDSU) is mediated through `CompanionInputRouter.slotDelegate`.
/// Until that module lands the session performs state management only.
@MainActor
public final class CompanionControllerSession: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var connectionState: CompanionConnectionState = .disconnected

    /// The system ID of the currently active layout (e.g. `"com.provenance.atari5200"`).
    @Published public var activeSystemID: String = ""

    /// The input router shared between this session and the active layout.
    @Published public private(set) var inputRouter: CompanionInputRouter

    // MARK: - Private

    private var connectionTask: Task<Void, Never>?
    private var lastHost: String?
    private var lastPort: UInt16?

    // MARK: - Init

    public init(inputRouter: CompanionInputRouter = CompanionInputRouter()) {
        self.inputRouter = inputRouter
    }

    // MARK: - Connection lifecycle

    /// Begin connecting to a DSU server at the given host and port.
    public func connect(host: String, port: UInt16 = 26760) {
        guard !connectionState.isConnecting, !connectionState.isConnected else { return }

        lastHost = host
        lastPort = port
        connectionState = .connecting(host: host, port: port)

        connectionTask = Task { [weak self] in
            await self?.performConnect(host: host, port: port)
        }
    }

    /// Disconnect from the current DSU server and reset state.
    ///
    /// The existing `inputRouter` instance is *reset* (state cleared) rather than
    /// replaced, so any `slotDelegate` wired to it (e.g. `CoreCompanionBridge`)
    /// remains valid after disconnect and does not need to be re-attached.
    @MainActor public func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        connectionState = .disconnected
        inputRouter.reset()
    }

    /// Retry connection after an error using the last known host/port.
    public func retry() {
        if case .error = connectionState, let host = lastHost, let port = lastPort {
            connectionState = .disconnected
            connect(host: host, port: port)
        } else if case .error = connectionState {
            connectionState = .disconnected
        }
    }

    // MARK: - Private helpers

    private func performConnect(host: String, port: UInt16) async {
        // TODO: Replace with real DSU handshake when PVControllerDSU lands.
        // This stub simulates a 1-second connection attempt.
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }

            // Validate the host is reachable using NWPathMonitor or a UDP probe.
            // For now we optimistically transition to connected with slot 0.
            connectionState = .connected(host: host, slotIndex: 0)
        } catch {
            guard !Task.isCancelled else { return }
            connectionState = .error(reason: error.localizedDescription)
        }
    }

    // MARK: - Pairing helpers

    /// Returns a URL that encodes the DSU server address for QR-code pairing.
    ///
    /// Format: `provenance://companion?host=<host>&port=<port>`
    public func pairingURL(host: String, port: UInt16 = 26760) -> URL? {
        var components = URLComponents()
        components.scheme = "provenance"
        components.host   = "companion"
        components.queryItems = [
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "port", value: String(port))
        ]
        return components.url
    }
}

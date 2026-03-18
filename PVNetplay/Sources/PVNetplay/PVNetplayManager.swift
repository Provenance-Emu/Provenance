//
//  PVNetplayManager.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(Combine)
import Combine
#endif

/// The central coordinator for netplay sessions.
///
/// `PVNetplayManager` is a Swift actor that owns session lifecycle, peer
/// discovery, and delegates to the appropriate core bridge (`PVNetplayCapable`).
///
/// The manager is the single source of truth for `NetplayState`. SwiftUI views
/// observe its `@Published` properties (via the `@MainActor` wrapper below).
public actor PVNetplayManager {
    /// Shared singleton for the running session.
    public static let shared = PVNetplayManager()

    // MARK: - State

    private(set) public var state: NetplayState = .idle {
        didSet {
            #if canImport(Combine)
            stateSubject.send(state)
            #endif
        }
    }

    #if canImport(Combine)
    // `nonisolated(unsafe)` is correct here: PassthroughSubject is internally
    // thread-safe for send() / subscribe(), and we only ever call send() from
    // within actor-isolated code (the `state` didSet). The nonisolated keyword
    // allows the computed `statePublisher` property below to read this subject
    // without needing actor isolation, satisfying Swift 6 strict concurrency.
    nonisolated(unsafe) private let stateSubject = PassthroughSubject<NetplayState, Never>()

    /// Publisher for state changes — always delivered on the main queue.
    public nonisolated var statePublisher: AnyPublisher<NetplayState, Never> {
        stateSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    #endif

    // MARK: - Dependencies (set after init)

    /// The currently active core bridge (set when a core starts emulation).
    private weak var activeBridge: (any PVNetplayCapable)?

    // MARK: - Registration

    /// Register the currently active emulator core.
    public func setActiveBridge(_ bridge: (any PVNetplayCapable)?) {
        activeBridge = bridge
    }

    // MARK: - Host

    /// Host a new netplay room with the given settings.
    public func host(settings: NetplaySettings) async throws {
        guard state == .idle else { throw NetplayError.alreadyActive }
        guard let bridge = activeBridge else { throw NetplayError.bridgeNotReady }
        guard bridge.supportsNetplay else { throw NetplayError.unsupported }

        let role = NetplayRole.host(port: settings.port)
        let placeholder = NetplayRoom(
            hostName: "Local Host",
            gameName: "Unknown",
            gameHash: "",
            coreIdentifier: "",
            maxPlayers: settings.maxPlayers,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: "0.0.0.0",
            port: settings.port
        )
        state = .connecting(to: placeholder)
        do {
            try await bridge.startNetplay(role: role, settings: settings)
            state = .hosting(room: placeholder)
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Join

    /// Join an existing netplay room.
    public func join(room: NetplayRoom, settings: NetplaySettings) async throws {
        guard state == .idle else { throw NetplayError.alreadyActive }
        guard let bridge = activeBridge else { throw NetplayError.bridgeNotReady }
        guard bridge.supportsNetplay else { throw NetplayError.unsupported }

        var joinSettings = settings
        joinSettings.playerIndex = 1
        let role = NetplayRole.client(host: room.hostAddress, port: room.port)
        state = .connecting(to: room)
        do {
            try await bridge.startNetplay(role: role, settings: joinSettings)
            let session = NetplaySession(
                room: room,
                role: role,
                peers: [],
                frameDelay: joinSettings.frameDelay,
                isRollbackEnabled: false
            )
            state = .connected(session: session)
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Spectate

    /// Join a room as a spectator.
    public func spectate(room: NetplayRoom) async throws {
        guard state == .idle else { throw NetplayError.alreadyActive }
        guard let bridge = activeBridge else { throw NetplayError.bridgeNotReady }
        guard bridge.supportsNetplay else { throw NetplayError.unsupported }

        let role = NetplayRole.spectator(host: room.hostAddress, port: room.port)
        let settings = NetplaySettings.defaultLAN
        state = .connecting(to: room)
        do {
            try await bridge.startNetplay(role: role, settings: settings)
            let session = NetplaySession(
                room: room,
                role: role,
                peers: [],
                frameDelay: settings.frameDelay,
                isRollbackEnabled: false
            )
            state = .connected(session: session)
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Disconnect

    /// Disconnect from the current session.
    public func disconnect() async {
        await activeBridge?.stopNetplay()
        state = .idle
    }
}

#if canImport(Combine)
// MARK: - ObservableNetplayManager (MainActor wrapper for SwiftUI)

/// `@MainActor` observable wrapper around `PVNetplayManager` for use in SwiftUI views.
@MainActor
public final class ObservableNetplayManager: ObservableObject {
    public static let shared = ObservableNetplayManager()

    @Published public private(set) var state: NetplayState = .idle
    @Published public private(set) var discoveredRooms: [NetplayRoom] = []

    private let manager = PVNetplayManager.shared
    public let bonjourDiscovery = PVNetplayBonjourDiscovery()

    private var cancellables = Set<AnyCancellable>()

    private init() {
        manager.statePublisher
            .assign(to: \.state, on: self)
            .store(in: &cancellables)

        bonjourDiscovery.$rooms
            .assign(to: \.discoveredRooms, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Convenience pass-throughs

    public func host(settings: NetplaySettings) async throws {
        try await manager.host(settings: settings)
    }

    public func join(room: NetplayRoom, settings: NetplaySettings) async throws {
        try await manager.join(room: room, settings: settings)
    }

    public func spectate(room: NetplayRoom) async throws {
        try await manager.spectate(room: room)
    }

    public func disconnect() async {
        await manager.disconnect()
    }

    public func startDiscovery() {
        bonjourDiscovery.startDiscovery()
    }

    public func stopDiscovery() {
        bonjourDiscovery.stopDiscovery()
    }
}
#endif

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
    public static let shared = PVNetplayManager(advertiser: PVNetplayManager.defaultAdvertiser())

    /// Publishes hosted rooms for cores that don't (`netplayAdvertisesOwnRoom`).
    private let advertiser: (any NetplayRoomAdvertising)?

    /// What the current LAN advertisement was built from; nil when none is published.
    private var advertisementContext: (settings: NetplaySettings, game: NetplayHostedGame?)?
    /// The TXT record last published, so a core that reports its room every
    /// tick (Dolphin polls at 1 Hz) doesn't republish an unchanged record.
    private var lastAdvertisedTXT: [String: String]?

    init(advertiser: (any NetplayRoomAdvertising)?) {
        self.advertiser = advertiser
    }

    private static func defaultAdvertiser() -> (any NetplayRoomAdvertising)? {
        #if canImport(Darwin)
        return NetServiceRoomAdvertiser()
        #else
        return nil
        #endif
    }

    // MARK: - State

    private(set) public var state: NetplayState = .idle {
        didSet {
            #if canImport(Combine)
            // Always send on the main queue so Combine subscribers (which may
            // subscribe/receive on main) never race with actor-background sends.
            let newState = state
            Task { @MainActor in
                self.stateSubject.send(newState)
            }
            #endif
        }
    }

    #if canImport(Combine)
    // `nonisolated(unsafe)` allows the computed `statePublisher` below to read
    // this subject without actor-hopping. Send is always dispatched to main (see
    // didSet above), so concurrent access between send and subscribe is avoided.
    nonisolated(unsafe) private let stateSubject = PassthroughSubject<NetplayState, Never>()

    /// Publisher for state changes — always delivered on the main queue.
    public nonisolated var statePublisher: AnyPublisher<NetplayState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    #endif

    // MARK: - Dependencies (set after init)

    /// The currently active core bridge (set when a core starts emulation).
    private weak var activeBridge: (any PVNetplayCapable)?

    // MARK: - Registration

    #if canImport(Combine)
    private var bridgeStateCancellable: AnyCancellable?
    #endif

    /// Register the currently active emulator core.
    public func setActiveBridge(_ bridge: (any PVNetplayCapable)?) async {
        // A session belongs to the core that started it. If that core went
        // away without disconnecting, don't leave a dead session blocking the next.
        if bridge !== activeBridge, state.isActive {
            state = .idle
            await withdrawAdvertisement()
        }
        activeBridge = bridge
        #if canImport(Combine)
        // @Sendable: the sink fires on the publisher's thread, outside the actor.
        // Xcode 26.3 rejects the non-Sendable form ("passing closure as a
        // 'sending' parameter risks causing data races").
        bridgeStateCancellable = bridge?.netplayStatePublisher.sink { @Sendable [weak self] bridgeState in
            Task { await self?.bridgeStateChanged(bridgeState) }
        }
        #endif
    }

    /// Follows what the core reports while a session is up: a host's room
    /// (player count), and a session the network ended (peer or host gone).
    func bridgeStateChanged(_ bridgeState: NetplayState) async {
        switch (state, bridgeState) {
        case (.hosting, .hosting(let room)):
            state = .hosting(room: room)
            // Republish the player count.
            if let context = advertisementContext,
               let advertised = Self.lanAdvertisement(for: room, settings: context.settings, game: context.game) {
                await advertise(advertised)
            }
        case (.connecting, .connected(let session)):
            // A core that reports its own connection (PPSSPP ad hoc,
            // Mednafen) finished connecting after `join` returned.
            state = .connected(session: session)
        case (.hosting, .disconnected(let reason)),
             (.connecting, .disconnected(let reason)),
             (.connected, .disconnected(let reason)):
            state = .disconnected(reason: reason)
            await withdrawAdvertisement()
        default:
            break
        }
    }

    // MARK: - Host

    /// Host a new netplay room with the given settings.
    ///
    /// - Parameter game: The game being hosted, published in the room's LAN
    ///   advertisement so joiners can find it in their library. Optional:
    ///   without it the room is still published, under the core's own details.
    public func host(settings: NetplaySettings, game: NetplayHostedGame? = nil) async throws {
        guard !state.isActive else { throw NetplayError.alreadyActive }
        guard let bridge = activeBridge else { throw NetplayError.bridgeNotReady }
        guard bridge.supportsNetplay else { throw NetplayError.unsupported }

        if let option = game?.option {
            guard (2...option.maxPlayers).contains(settings.maxPlayers),
                  !settings.allowSpectators || option.core.supportsSpectators else {
                throw NetplayError.invalidSettings("Player or spectator settings exceed this game's multiplayer mode.")
            }
        }

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
            // Prefer the room the core describes (game, port, player count).
            let hostedRoom: NetplayRoom
            if case .hosting(let room) = bridge.netplayState {
                hostedRoom = room
            } else {
                hostedRoom = placeholder
            }
            state = .hosting(room: hostedRoom)
            if !bridge.netplayAdvertisesOwnRoom,
               let advertised = Self.lanAdvertisement(for: hostedRoom, settings: settings, game: game) {
                advertisementContext = (settings, game)
                await advertise(advertised)
            }
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Join

    /// Join an existing netplay room.
    public func join(room: NetplayRoom, settings: NetplaySettings) async throws {
        guard !room.isFull else { throw NetplayError.sessionFull }
        guard !state.isActive else { throw NetplayError.alreadyActive }
        guard let bridge = activeBridge else { throw NetplayError.bridgeNotReady }
        guard bridge.supportsNetplay else { throw NetplayError.unsupported }

        var joinSettings = settings
        joinSettings.playerIndex = 1
        joinSettings.relayServer = Self.relayServer(forJoining: room, stored: settings.relayServer)
        let role = NetplayRole.client(host: room.hostAddress, port: room.port)
        state = .connecting(to: room)
        do {
            try await bridge.startNetplay(role: role, settings: joinSettings)
            switch bridge.netplayState {
            case .connecting:
                // The core is still connecting and will report `.connected`.
                break
            case .connected(let session):
                state = .connected(session: session)
            default:
                state = .connected(session: NetplaySession(
                    room: room,
                    role: role,
                    peers: [],
                    frameDelay: joinSettings.frameDelay,
                    isRollbackEnabled: false
                ))
            }
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Spectate

    /// Join a room as a spectator.
    public func spectate(room: NetplayRoom, settings: NetplaySettings = .defaultLAN) async throws {
        guard room.allowsSpectators else { throw NetplayError.invalidSettings("This room does not allow spectators.") }
        guard !state.isActive else { throw NetplayError.alreadyActive }
        guard let bridge = activeBridge else { throw NetplayError.bridgeNotReady }
        guard bridge.supportsNetplay else { throw NetplayError.unsupported }

        let role = NetplayRole.spectator(host: room.hostAddress, port: room.port)
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

    // MARK: - Start

    /// Host only: start the game for everyone who has joined, for cores that
    /// need it (`netplayHostStartsGame`). A no-op otherwise.
    public func startGame() async throws {
        guard case .hosting = state else { return }
        guard let bridge = activeBridge else { throw NetplayError.bridgeNotReady }
        try await bridge.startNetplayGame()
    }

    /// Whether hosting would restart the running game.
    public var hostingRestartsGame: Bool {
        activeBridge?.netplayHostingRestartsGame ?? false
    }

    /// Disconnect from the current session.
    public func disconnect() async {
        await activeBridge?.stopNetplay()
        state = .idle
        await withdrawAdvertisement()
    }

    // MARK: - Lobby launch

    /// Set by the library lobby just before it launches a game; taken by the
    /// emulator once the game's core has started.
    private var pendingLaunchIntent: NetplayLaunchIntent?

    /// Remember what to do once the game `intent.gameMD5` has booted.
    /// Replaces any earlier intent.
    public func setLaunchIntent(_ intent: NetplayLaunchIntent?) {
        pendingLaunchIntent = intent
    }

    /// The pending intent, if it is for the game `md5` and hasn't expired.
    /// An intent is taken at most once; any other launch discards it.
    public func takeLaunchIntent(forGameMD5 md5: String, at now: Date = Date()) -> NetplayLaunchIntent? {
        defer { pendingLaunchIntent = nil }
        guard let intent = pendingLaunchIntent, intent.applies(toGameMD5: md5, at: now) else { return nil }
        return intent
    }

    /// Wait until the active bridge supports netplay, which a thin core
    /// reports only once its netpacket interface registers after boot.
    /// - Returns: false when there is no bridge or it isn't ready in time.
    public func waitUntilNetplayReady(timeout: Duration = .seconds(15), pollInterval: Duration = .milliseconds(250)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while true {
            if activeBridge?.supportsNetplay == true { return true }
            guard ContinuousClock.now < deadline, !Task.isCancelled else { return false }
            try? await Task.sleep(for: pollInterval)
        }
    }

    // MARK: - LAN advertisement

    private func advertise(_ room: NetplayRoom) async {
        let txt = NetplayRoomTXTRecord.txtRecord(for: room)
        guard txt != lastAdvertisedTXT else { return }
        lastAdvertisedTXT = txt
        await advertiser?.advertise(room)
    }

    private func withdrawAdvertisement() async {
        guard advertisementContext != nil else { return }
        advertisementContext = nil
        lastAdvertisedTXT = nil
        await advertiser?.withdraw()
    }

    /// The room to publish on the local network for a hosted session, or nil
    /// when the session isn't reachable directly on the LAN: it goes through a
    /// relay or traversal server, or its port is unknown.
    static func lanAdvertisement(
        for hosted: NetplayRoom,
        settings: NetplaySettings,
        game: NetplayHostedGame?
    ) -> NetplayRoom? {
        guard settings.relayServer == nil, hosted.traversalCode == nil else { return nil }
        let port = hosted.port > 0 ? hosted.port : settings.port
        guard port > 0 else { return nil }

        func firstNonEmpty(_ values: String?...) -> String {
            values.lazy.compactMap { $0 }.first { !$0.isEmpty } ?? ""
        }
        return NetplayRoom(
            id: hosted.id,
            hostName: firstNonEmpty(settings.roomName, settings.nickname, hosted.hostName),
            gameName: firstNonEmpty(game?.name, hosted.gameName),
            gameHash: firstNonEmpty(game?.md5, hosted.gameHash),
            coreIdentifier: firstNonEmpty(hosted.coreIdentifier, game?.coreIdentifier),
            maxPlayers: hosted.maxPlayers,
            currentPlayers: hosted.currentPlayers,
            isLAN: true,
            hostAddress: hosted.hostAddress,
            port: port,
            isPasswordProtected: settings.password != nil,
            allowsSpectators: settings.allowSpectators,
            spectatorCount: hosted.spectatorCount,
            discoverySource: .bonjour,
            gameSerial: firstNonEmpty(game?.serial, hosted.gameSerial),
            systemIdentifier: firstNonEmpty(game?.systemIdentifier, hosted.systemIdentifier),
            coreVersion: firstNonEmpty(game?.coreVersion, hosted.coreVersion),
            playMode: game?.option?.mode ?? hosted.playMode
        )
    }

    /// The relay to use when joining `room`. A room found on the LAN is joined
    /// directly, whatever relay the joiner has stored: Dolphin would otherwise
    /// take the host's address for a traversal code. A room the host reached
    /// through traversal is joined with its code.
    static func relayServer(forJoining room: NetplayRoom, stored: String?) -> String? {
        if let code = room.traversalCode, !code.isEmpty { return code }
        if room.discoverySource == .bonjour { return nil }
        return stored
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

    public func host(settings: NetplaySettings, game: NetplayHostedGame? = nil) async throws {
        try await manager.host(settings: settings, game: game)
    }

    public func join(room: NetplayRoom, settings: NetplaySettings) async throws {
        try await manager.join(room: room, settings: settings)
    }

    public func spectate(room: NetplayRoom, settings: NetplaySettings = .defaultLAN) async throws {
        try await manager.spectate(room: room, settings: settings)
    }

    public func disconnect() async {
        await manager.disconnect()
    }

    public func startGame() async throws {
        try await manager.startGame()
    }

    public func hostingRestartsGame() async -> Bool {
        await manager.hostingRestartsGame
    }

    public func setLaunchIntent(_ intent: NetplayLaunchIntent?) async {
        await manager.setLaunchIntent(intent)
    }

    public func startDiscovery() {
        bonjourDiscovery.startDiscovery()
    }

    public func stopDiscovery() {
        bonjourDiscovery.stopDiscovery()
    }
}
#endif

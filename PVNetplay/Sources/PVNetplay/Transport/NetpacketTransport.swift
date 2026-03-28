//
//  NetpacketTransport.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Network.framework-based transport for the libretro netpacket interface
//  (RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE, env 78).
//
//  Provides UDP (unreliable) and TCP (reliable) packet routing between a host
//  and one or more clients. The host assigns client IDs; the host itself is
//  always client ID 0.
//

import Foundation
import Network
import os.lock

/// Netpacket flag constants mirroring libretro.h definitions.
public struct NetpacketFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Default unreliable delivery (UDP).
    public static let unreliable   = NetpacketFlags([])
    /// Reliable, ordered delivery (TCP).
    public static let reliable     = NetpacketFlags(rawValue: 1 << 0)
    /// Reliable but unsequenced delivery.
    public static let unsequenced  = NetpacketFlags(rawValue: 1 << 1)
    /// Hint that the send buffer should be flushed immediately.
    public static let flushHint    = NetpacketFlags(rawValue: 1 << 2)

    /// Broadcast to all connected peers.
    public static let broadcastID: UInt16 = 0xFFFF
}

/// A received netpacket queued for delivery to the core.
public struct NetpacketMessage: Sendable {
    public let data: Data
    public let fromClient: UInt16
}

/// Thread-safe one-shot flag for continuation resumption.
private final class AtomicOnce: @unchecked Sendable {
    private var _done = false
    private var _lock = os_unfair_lock()

    /// Returns `true` exactly once; all subsequent calls return `false`.
    func tryOnce() -> Bool {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        if _done { return false }
        _done = true
        return true
    }
}

/// Network.framework-based transport for libretro netpacket multiplayer.
///
/// In host mode, creates an `NWListener` on the specified port and assigns
/// sequential client IDs to connecting peers. In client mode, connects to a
/// host and receives an assigned client ID during the handshake.
///
/// Incoming packets are queued and drained synchronously by the emulation
/// thread via `dequeueReceived()`.
public final class NetpacketTransport: @unchecked Sendable {

    // MARK: - Types

    /// Role this transport instance plays in the session.
    public enum Role: Sendable {
        case host(port: UInt16)
        case client(host: String, port: UInt16)
    }

    /// Internal connection state for each peer.
    private struct PeerConnection {
        let clientID: UInt16
        let udpConnection: NWConnection
        var tcpConnection: NWConnection?
    }

    // MARK: - Public properties

    /// The role of this transport instance.
    public let role: Role

    /// The locally-assigned client ID (host is always 0).
    public private(set) var localClientID: UInt16 = 0

    /// Called on the network queue when a new peer connects.
    public var onPeerConnected: (@Sendable (UInt16) -> Void)?

    /// Called on the network queue when a peer disconnects.
    public var onPeerDisconnected: (@Sendable (UInt16) -> Void)?

    // MARK: - Private state

    /// Key used to detect re-entrant calls on `queue` (prevents deadlock in `stop()`).
    private static let queueKey = DispatchSpecificKey<Bool>()
    private let queue: DispatchQueue = {
        let q = DispatchQueue(label: "com.provenance.netpacket-transport", qos: .userInteractive)
        q.setSpecific(key: NetpacketTransport.queueKey, value: true)
        return q
    }()
    private var listener: NWListener?
    private var tcpListener: NWListener?
    private var peers: [UInt16: PeerConnection] = [:]
    private var nextClientID: UInt16 = 1
    private var hostConnection: NWConnection?
    private var hostTCPConnection: NWConnection?
    private var incomingQueue: [NetpacketMessage] = []
    private var queueLock = os_unfair_lock()

    /// Handshake: 4-byte magic "PVNP" + 2-byte assigned client ID (network byte order).
    private static let handshakeMagic: [UInt8] = [0x50, 0x56, 0x4E, 0x50]
    private static let handshakeSize = 6

    // MARK: - Init

    public init(role: Role) {
        self.role = role
        if case .host = role {
            self.localClientID = 0
        }
    }

    deinit {
        cancelAllConnections()
    }

    // MARK: - Lifecycle

    /// Start the transport. For hosts, begins listening. For clients, connects.
    public func start() async throws {
        switch role {
        case .host(let port):
            try await startHost(port: port)
        case .client(let host, let port):
            try await startClient(host: host, port: port)
        }
    }

    /// Stop the transport, closing all connections.
    /// Safe to call from any thread, including from peer callbacks on the transport queue.
    public func stop() {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            cancelAllConnectionsUnsafe()
        } else {
            queue.sync { cancelAllConnectionsUnsafe() }
        }
        os_unfair_lock_lock(&queueLock)
        incomingQueue.removeAll()
        os_unfair_lock_unlock(&queueLock)
    }

    /// Cancel all connections without queue synchronization.
    /// Called from `deinit` (where we're the sole owner) and from `stop()` when
    /// already executing on the transport queue.
    private func cancelAllConnections() {
        listener?.cancel()
        tcpListener?.cancel()
        for (_, peer) in peers {
            peer.udpConnection.cancel()
            peer.tcpConnection?.cancel()
        }
        hostConnection?.cancel()
        hostTCPConnection?.cancel()
    }

    /// Cancel and nil all connections. Must be called on `queue`.
    private func cancelAllConnectionsUnsafe() {
        listener?.cancel()
        listener = nil
        tcpListener?.cancel()
        tcpListener = nil
        for (_, peer) in peers {
            peer.udpConnection.cancel()
            peer.tcpConnection?.cancel()
        }
        peers.removeAll()
        hostConnection?.cancel()
        hostConnection = nil
        hostTCPConnection?.cancel()
        hostTCPConnection = nil
    }

    // MARK: - Send

    /// Send a packet to a specific client or broadcast.
    /// - Parameters:
    ///   - data: Raw packet payload.
    ///   - clientID: Target client ID, or `NetpacketFlags.broadcastID` for all peers.
    ///   - flags: Delivery flags (reliable, unsequenced, flush hint).
    public func send(data: Data, to clientID: UInt16, flags: Int32) {
        let netFlags = NetpacketFlags(rawValue: flags)
        let useReliable = netFlags.contains(.reliable)

        queue.async { [weak self] in
            guard let self else { return }

            if clientID == NetpacketFlags.broadcastID {
                for (_, peer) in self.peers {
                    self.sendToPeer(peer, data: data, reliable: useReliable)
                }
                if let hostConn = self.hostConnection {
                    self.sendOnConnection(useReliable ? self.hostTCPConnection ?? hostConn : hostConn, data: data)
                }
            } else {
                if let peer = self.peers[clientID] {
                    self.sendToPeer(peer, data: data, reliable: useReliable)
                } else if clientID == 0, let hostConn = self.hostConnection {
                    self.sendOnConnection(useReliable ? self.hostTCPConnection ?? hostConn : hostConn, data: data)
                }
            }
        }
    }

    // MARK: - Receive queue

    /// Drain all queued incoming packets. Called synchronously from the emulation thread.
    public func dequeueReceived() -> [NetpacketMessage] {
        os_unfair_lock_lock(&queueLock)
        let messages = incomingQueue
        incomingQueue.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(&queueLock)
        return messages
    }

    /// Enqueue a received packet (called from the network receive path).
    private func enqueue(_ message: NetpacketMessage) {
        os_unfair_lock_lock(&queueLock)
        incomingQueue.append(message)
        os_unfair_lock_unlock(&queueLock)
    }

    // MARK: - Host

    private func startHost(port: UInt16) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = AtomicOnce()

            queue.async { [weak self] in
                guard let self else {
                    if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.cancelled) }
                    return
                }

                let udpParams = NWParameters.udp
                udpParams.allowLocalEndpointReuse = true

                guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                    if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.connectionFailed("Invalid port \(port)")) }
                    return
                }

                do {
                    let udpListener = try NWListener(using: udpParams, on: endpointPort)
                    self.listener = udpListener

                    udpListener.stateUpdateHandler = { [weak self] state in
                        switch state {
                        case .ready:
                            if once.tryOnce() { continuation.resume() }
                        case .failed(let error):
                            if once.tryOnce() { continuation.resume(throwing: error) }
                            self?.listener = nil
                        case .cancelled:
                            if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.cancelled) }
                        default:
                            break
                        }
                    }

                    udpListener.newConnectionHandler = { [weak self] connection in
                        self?.handleNewPeerConnection(connection)
                    }

                    udpListener.start(queue: self.queue)
                } catch {
                    if once.tryOnce() { continuation.resume(throwing: error) }
                }

                // TCP sideband listener for reliable packets (optional, skipped if port would wrap)
                let tcpPort = port &+ 1
                if tcpPort > port, let tcpEndpointPort = NWEndpoint.Port(rawValue: tcpPort) {
                    let tcpParams = NWParameters.tcp
                    tcpParams.allowLocalEndpointReuse = true
                    do {
                        let tcpListen = try NWListener(using: tcpParams, on: tcpEndpointPort)
                        self.tcpListener = tcpListen
                        tcpListen.newConnectionHandler = { [weak self] connection in
                            self?.handleNewTCPPeerConnection(connection)
                        }
                        tcpListen.start(queue: self.queue)
                    } catch {
                        // TCP sideband is best-effort; continue without it
                    }
                }
            }
        }
    }

    private func handleNewPeerConnection(_ connection: NWConnection) {
        let clientID = nextClientID
        nextClientID += 1

        let peer = PeerConnection(clientID: clientID, udpConnection: connection, tcpConnection: nil)
        peers[clientID] = peer

        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.removePeer(clientID)
            } else if case .cancelled = state {
                self?.removePeer(clientID)
            }
        }

        connection.start(queue: queue)
        sendHandshake(on: connection, assignedID: clientID)
        receiveLoop(on: connection, fromClient: clientID)
        onPeerConnected?(clientID)
    }

    private func handleNewTCPPeerConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: Self.handshakeSize, maximumLength: Self.handshakeSize) { [weak self] data, _, _, error in
            guard let self, let data, error == nil, data.count >= Self.handshakeSize else { return }
            let magic = [UInt8](data.prefix(4))
            guard magic == Self.handshakeMagic else { return }
            let clientID = data.withUnsafeBytes { buf -> UInt16 in
                buf.loadUnaligned(fromByteOffset: 4, as: UInt16.self).bigEndian
            }
            if var peer = self.peers[clientID] {
                peer.tcpConnection = connection
                self.peers[clientID] = peer
                self.receiveLoop(on: connection, fromClient: clientID)
            }
        }
    }

    private func removePeer(_ clientID: UInt16) {
        guard let peer = peers.removeValue(forKey: clientID) else { return }
        peer.udpConnection.cancel()
        peer.tcpConnection?.cancel()
        onPeerDisconnected?(clientID)
    }

    // MARK: - Client

    private func startClient(host: String, port: UInt16) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = AtomicOnce()

            queue.async { [weak self] in
                guard let self else {
                    if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.cancelled) }
                    return
                }

                guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                    if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.connectionFailed("Invalid port \(port)")) }
                    return
                }

                let hostEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: endpointPort)
                let connection = NWConnection(to: hostEndpoint, using: .udp)
                self.hostConnection = connection

                connection.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        guard let self else { return }
                        self.sendHandshake(on: connection, assignedID: 0)
                        connection.receive(minimumIncompleteLength: Self.handshakeSize, maximumLength: 65535) { [weak self] data, _, _, error in
                            if let error {
                                if once.tryOnce() { continuation.resume(throwing: error) }
                                return
                            }
                            guard let data, data.count >= Self.handshakeSize else {
                                if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.handshakeFailed) }
                                return
                            }
                            let magic = [UInt8](data.prefix(4))
                            guard magic == Self.handshakeMagic else {
                                if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.handshakeFailed) }
                                return
                            }
                            let assignedID = data.withUnsafeBytes { buf -> UInt16 in
                                buf.loadUnaligned(fromByteOffset: 4, as: UInt16.self).bigEndian
                            }
                            self?.localClientID = assignedID
                            if once.tryOnce() { continuation.resume() }
                            self?.receiveLoop(on: connection, fromClient: 0)

                            // Establish TCP sideband for reliable packets (skipped if port would wrap)
                            let tcpPort = port &+ 1
                            if tcpPort > port, let tcpEndpointPort = NWEndpoint.Port(rawValue: tcpPort) {
                                let tcpEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: tcpEndpointPort)
                                let tcpConn = NWConnection(to: tcpEndpoint, using: .tcp)
                                self?.hostTCPConnection = tcpConn
                                let transportQueue = self?.queue ?? .global()
                                tcpConn.start(queue: transportQueue)
                                tcpConn.stateUpdateHandler = { [weak self] tcpState in
                                    if case .ready = tcpState, let self {
                                        var handshake = Data(Self.handshakeMagic)
                                        var netID = assignedID.bigEndian
                                        handshake.append(Data(bytes: &netID, count: 2))
                                        tcpConn.send(content: handshake, completion: .contentProcessed({ _ in }))
                                        self.receiveLoop(on: tcpConn, fromClient: 0)
                                    }
                                }
                            }
                        }
                    case .failed(let error):
                        if once.tryOnce() { continuation.resume(throwing: error) }
                    case .cancelled:
                        if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.cancelled) }
                    default:
                        break
                    }
                }

                connection.start(queue: self.queue)
            }
        }
    }

    // MARK: - Helpers

    private func sendHandshake(on connection: NWConnection, assignedID: UInt16) {
        var handshake = Data(Self.handshakeMagic)
        var netID = assignedID.bigEndian
        handshake.append(Data(bytes: &netID, count: 2))
        connection.send(content: handshake, completion: .contentProcessed({ _ in }))
    }

    private func sendToPeer(_ peer: PeerConnection, data: Data, reliable: Bool) {
        let conn = reliable ? (peer.tcpConnection ?? peer.udpConnection) : peer.udpConnection
        sendOnConnection(conn, data: data)
    }

    private func sendOnConnection(_ connection: NWConnection, data: Data) {
        connection.send(content: data, completion: .contentProcessed({ error in
            if let error {
                os_log(.error, "NetpacketTransport send error: %{public}@", error.localizedDescription)
            }
        }))
    }

    private func receiveLoop(on connection: NWConnection, fromClient clientID: UInt16) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                // Skip handshake packets in the data stream
                if data.count >= Self.handshakeSize {
                    let prefix = [UInt8](data.prefix(4))
                    if prefix == Self.handshakeMagic {
                        self.receiveLoop(on: connection, fromClient: clientID)
                        return
                    }
                }
                self.enqueue(NetpacketMessage(data: data, fromClient: clientID))
            }
            if error == nil {
                self.receiveLoop(on: connection, fromClient: clientID)
            }
        }
    }
}

// MARK: - Errors

/// Errors specific to `NetpacketTransport`.
public enum NetpacketTransportError: Error, LocalizedError, Sendable {
    case cancelled
    case handshakeFailed
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Netpacket transport was cancelled."
        case .handshakeFailed:
            return "Netpacket handshake failed — peer may not support this protocol."
        case .connectionFailed(let reason):
            return "Netpacket connection failed: \(reason)"
        }
    }
}

//
//  NetpacketTransport.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Network.framework transport for the libretro netpacket interface
//  (RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE, env 78).
//
//  Every packet travels over one TCP connection per client. libretro requires
//  a frontend to support reliable delivery and lets it deliver "unreliable"
//  packets reliably too, which is also what RetroArch does. TCP gives ordering,
//  framing and disconnect detection for free.
//
//  The host is always client 0 and assigns every client an ID. Clients only
//  talk to the host; the host relays packets addressed to another client or
//  broadcast, so every player can reach every other player.
//

import Foundation
import Network
import os.lock

/// Netpacket flag constants mirroring libretro.h definitions.
public struct NetpacketFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// May be dropped. Delivered reliably here, which libretro allows.
    public static let unreliable   = NetpacketFlags([])
    /// Reliable, ordered delivery.
    public static let reliable     = NetpacketFlags(rawValue: 1 << 0)
    /// May arrive out of order. Delivered in order here.
    public static let unsequenced  = NetpacketFlags(rawValue: 1 << 1)
    /// Send buffered packets now. Packets are never buffered here.
    public static let flushHint    = NetpacketFlags(rawValue: 1 << 2)

    /// Broadcast to all connected peers.
    public static let broadcastID: UInt16 = 0xFFFF
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

/// Network.framework transport for libretro netpacket multiplayer.
///
/// All callbacks run on the transport's private queue. `stop()` clears them,
/// so none fires once it returns.
public final class NetpacketTransport: @unchecked Sendable {

    // MARK: - Types

    /// Role this transport instance plays in the session.
    public enum Role: Sendable {
        case host(port: UInt16)
        case client(host: String, port: UInt16)
    }

    /// The client ID of the host.
    public static let hostID: UInt16 = 0

    /// The Bonjour service type hosts advertise and `PVNetplayBonjourDiscovery`
    /// browses. Must also be listed under `NSBonjourServices` in the apps' Info.plists.
    public static let bonjourServiceType = "_provenance-np._tcp"

    /// libretro caps a netpacket at 64 KB.
    public static let maxPayloadSize = 64 * 1024

    /// How long a connection may take to complete the handshake.
    static let handshakeTimeout: TimeInterval = 10

    // MARK: - Public properties

    /// The role of this transport instance.
    public let role: Role

    /// Peers must report the same version. The core's netpacket
    /// `protocol_version`, or its name and version when it has none.
    public let protocolVersion: String

    /// The most clients a host accepts.
    public let maxClients: Int

    /// The local client ID (host is always 0; a client's is set by the host).
    public private(set) var localClientID: UInt16 = NetpacketTransport.hostID

    /// Host: the port it listens on, once started. Differs from the requested
    /// port when that was 0 (any free port).
    public private(set) var listeningPort: UInt16?

    /// Host only: a client finished the handshake.
    public var onPeerConnected: (@Sendable (UInt16) -> Void)?

    /// Host only: a client left or its connection died.
    public var onPeerDisconnected: (@Sendable (UInt16) -> Void)?

    /// A packet arrived for this player: payload and the sender's client ID.
    public var onPacket: (@Sendable (Data, UInt16) -> Void)?

    /// Client only: the host accepted us and assigned this client ID. Called
    /// before any `onPacket`, so the core can be started before packets flow.
    public var onWelcomed: (@Sendable (UInt16) -> Void)?

    /// The session ended without `stop()`: the client lost the host, or the
    /// host's listener failed.
    public var onSessionEnded: (@Sendable (NetpacketTransportError) -> Void)?

    /// Host: advertise the room on the local network under
    /// `bonjourServiceType` with this name and TXT record. Set before `start()`.
    /// The player count (`players`) is kept up to date.
    public var bonjourAdvertisement: (name: String, txtRecord: [String: String])?

    // MARK: - Private state

    /// Key used to detect re-entrant calls on `queue` (prevents deadlock in `stop()`).
    private static let queueKey = DispatchSpecificKey<Bool>()
    private let queue: DispatchQueue = {
        let q = DispatchQueue(label: "com.provenance.netpacket-transport", qos: .userInteractive)
        q.setSpecific(key: NetpacketTransport.queueKey, value: true)
        return q
    }()
    private var listener: NWListener?
    /// Host: clients that finished the handshake.
    private var peers: [UInt16: NWConnection] = [:]
    /// Host: connections still in the handshake.
    private var pendingConnections: [ObjectIdentifier: NWConnection] = [:]
    private var nextClientID: UInt16 = 1
    /// Client: the connection to the host.
    private var hostConnection: NWConnection?
    /// Client: the host accepted the handshake.
    private var welcomed = false
    private var stopped = false

    // MARK: - Init

    public init(role: Role, protocolVersion: String = "", maxClients: Int = 15) {
        self.role = role
        self.protocolVersion = protocolVersion
        self.maxClients = max(1, maxClients)
    }

    deinit {
        listener?.cancel()
        peers.values.forEach { $0.cancel() }
        pendingConnections.values.forEach { $0.cancel() }
        hostConnection?.cancel()
    }

    /// The client IDs of connected peers (host only).
    public var connectedPeerIDs: [UInt16] {
        onQueue { peers.keys.sorted() }
    }

    // MARK: - Lifecycle

    /// Start the transport. A host starts listening; a client connects and
    /// completes the handshake, after which `localClientID` is set.
    public func start() async throws {
        switch role {
        case .host(let port):
            try await startHost(port: port)
        case .client(let host, let port):
            try await startClient(host: host, port: port)
        }
    }

    /// Close every connection and clear the callbacks, so none fires after
    /// this returns. Safe to call from any thread, including from a callback.
    public func stop() {
        onQueue {
            stopped = true
            onPeerConnected = nil
            onPeerDisconnected = nil
            onPacket = nil
            onWelcomed = nil
            onSessionEnded = nil
            listener?.cancel()
            listener = nil
            peers.values.forEach { $0.cancel() }
            peers.removeAll()
            pendingConnections.values.forEach { $0.cancel() }
            pendingConnections.removeAll()
            hostConnection?.cancel()
            hostConnection = nil
        }
    }

    /// Host only: drop a client, for example because the core refused it.
    public func disconnectPeer(_ clientID: UInt16) {
        queue.async { [weak self] in
            self?.removePeer(clientID)
        }
    }

    // MARK: - Send

    /// Send a packet to a client, the host, or everyone.
    /// - Parameters:
    ///   - data: The core's packet.
    ///   - clientID: Target client ID, or `NetpacketFlags.broadcastID` for all players.
    ///   - flags: Delivery flags. Every packet is delivered reliably and in order.
    public func send(data: Data, to clientID: UInt16, flags: Int32) {
        guard data.count <= Self.maxPayloadSize else {
            os_log(.error, "NetpacketTransport: dropping %d-byte packet over the 64 KB limit", data.count)
            return
        }
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            let frame = Frame(kind: .data, from: self.localClientID, to: clientID, payload: data)
            switch self.role {
            case .host:
                if clientID == NetpacketFlags.broadcastID {
                    self.peers.values.forEach { self.sendFrame(frame, on: $0) }
                } else if let peer = self.peers[clientID] {
                    self.sendFrame(frame, on: peer)
                }
            case .client:
                guard clientID != self.localClientID, let host = self.hostConnection else { return }
                self.sendFrame(frame, on: host)
            }
        }
    }

    // MARK: - Helpers

    /// Runs `body` on the transport queue, inline when already on it.
    private func onQueue<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            return body()
        }
        return queue.sync(execute: body)
    }

    /// TCP with Nagle off (packets are small and latency-sensitive) and
    /// keepalive on, so a peer that vanishes is noticed within ~15 s even
    /// while the game is paused and the core sends nothing.
    private static func tcpParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        tcp.keepaliveInterval = 2
        tcp.keepaliveCount = 5
        tcp.connectionTimeout = Int(handshakeTimeout)
        return NWParameters(tls: nil, tcp: tcp)
    }

    private func endSession(_ error: NetpacketTransportError) {
        guard !stopped else { return }
        let handler = onSessionEnded
        stop()
        handler?(error)
    }

    private func sendFrame(_ frame: Frame, on connection: NWConnection) {
        connection.send(content: Self.encode(frame), completion: .contentProcessed { error in
            if let error {
                os_log(.error, "NetpacketTransport send error: %{public}@", error.localizedDescription)
            }
        })
    }

    /// Reads one frame. `completion` gets nil when the connection ends or the
    /// frame is malformed.
    private func receiveFrame(on connection: NWConnection, completion: @escaping @Sendable (Frame?) -> Void) {
        connection.receive(minimumIncompleteLength: Self.headerSize, maximumLength: Self.headerSize) { header, _, _, error in
            guard error == nil, let header, let decoded = Self.decodeHeader(header) else {
                completion(nil)
                return
            }
            guard decoded.length > 0 else {
                completion(Frame(kind: decoded.kind, from: decoded.from, to: decoded.to, payload: Data()))
                return
            }
            connection.receive(minimumIncompleteLength: decoded.length, maximumLength: decoded.length) { payload, _, _, error in
                guard error == nil, let payload, payload.count == decoded.length else {
                    completion(nil)
                    return
                }
                completion(Frame(kind: decoded.kind, from: decoded.from, to: decoded.to, payload: payload))
            }
        }
    }

    /// Reads data frames until the connection ends.
    private func receiveLoop(on connection: NWConnection, peer: UInt16) {
        receiveFrame(on: connection) { [weak self] frame in
            guard let self, !self.stopped else { return }
            guard let frame else {
                // Closed by the other side or malformed: drop it.
                if case .host = self.role {
                    self.removePeer(peer)
                } else {
                    self.endSession(.hostClosed)
                }
                return
            }
            if frame.kind == .data {
                switch self.role {
                case .host:
                    self.route(frame, fromPeer: peer)
                case .client:
                    self.onPacket?(frame.payload, frame.from)
                }
            }
            self.receiveLoop(on: connection, peer: peer)
        }
    }
}

// MARK: - Host

extension NetpacketTransport {

    private func startHost(port: UInt16) async throws {
        let endpointPort: NWEndpoint.Port = port == 0 ? .any : NWEndpoint.Port(rawValue: port) ?? .any
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = AtomicOnce()
            queue.async { [weak self] in
                guard let self, !self.stopped else {
                    if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.cancelled) }
                    return
                }
                let parameters = Self.tcpParameters()
                parameters.allowLocalEndpointReuse = true
                let listener: NWListener
                do {
                    listener = try NWListener(using: parameters, on: endpointPort)
                } catch {
                    if once.tryOnce() { continuation.resume(throwing: error) }
                    return
                }
                self.listener = listener

                listener.stateUpdateHandler = { [weak self, weak listener] state in
                    switch state {
                    case .ready:
                        self?.listeningPort = listener?.port?.rawValue
                        if once.tryOnce() { continuation.resume() }
                    case .failed(let error):
                        if once.tryOnce() {
                            continuation.resume(throwing: error)
                        } else {
                            self?.endSession(.connectionFailed(error.localizedDescription))
                        }
                    case .cancelled:
                        if once.tryOnce() { continuation.resume(throwing: NetpacketTransportError.cancelled) }
                    default:
                        break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    self?.acceptConnection(connection)
                }
                self.updateAdvertisement()
                listener.start(queue: self.queue)
            }
        }
    }

    private func acceptConnection(_ connection: NWConnection) {
        guard !stopped else {
            connection.cancel()
            return
        }
        let key = ObjectIdentifier(connection)
        pendingConnections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.pendingConnections.removeValue(forKey: key)
            default:
                break
            }
        }
        connection.start(queue: queue)

        queue.asyncAfter(deadline: .now() + Self.handshakeTimeout) { [weak self, weak connection] in
            guard let self, let connection,
                  self.pendingConnections.removeValue(forKey: ObjectIdentifier(connection)) != nil else { return }
            connection.cancel()
        }

        receiveFrame(on: connection) { [weak self] frame in
            guard let self, self.pendingConnections.removeValue(forKey: key) != nil else { return }
            guard let frame, frame.kind == .hello,
                  let peerVersion = Self.protocolVersion(fromHello: frame.payload) else {
                connection.cancel()
                return
            }
            if peerVersion != self.protocolVersion {
                self.reject(connection, reason: "Different core version (host: \(self.protocolVersion), you: \(peerVersion))")
                return
            }
            guard self.peers.count < self.maxClients, let clientID = self.allocateClientID() else {
                self.reject(connection, reason: "The room is full")
                return
            }
            self.admit(connection, as: clientID)
        }
    }

    private func admit(_ connection: NWConnection, as clientID: UInt16) {
        peers[clientID] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.removePeer(clientID)
            default:
                break
            }
        }
        sendFrame(Frame(kind: .welcome, from: Self.hostID, to: clientID, payload: Data()), on: connection)
        updateAdvertisement()
        onPeerConnected?(clientID)
        receiveLoop(on: connection, peer: clientID)
    }

    private func reject(_ connection: NWConnection, reason: String) {
        let frame = Frame(kind: .reject, from: Self.hostID, to: 0, payload: Data(reason.utf8))
        connection.send(content: Self.encode(frame), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func allocateClientID() -> UInt16? {
        for _ in 0..<Int(UInt16.max) {
            let candidate = nextClientID
            nextClientID = nextClientID &+ 1
            if nextClientID == NetpacketFlags.broadcastID || nextClientID == Self.hostID {
                nextClientID = 1
            }
            if candidate != Self.hostID, candidate != NetpacketFlags.broadcastID, peers[candidate] == nil {
                return candidate
            }
        }
        return nil
    }

    private func removePeer(_ clientID: UInt16) {
        guard let connection = peers.removeValue(forKey: clientID) else { return }
        connection.cancel()
        updateAdvertisement()
        onPeerDisconnected?(clientID)
    }

    /// Host: (re)publish the Bonjour record with the current player count.
    private func updateAdvertisement() {
        guard let listener, let advertisement = bonjourAdvertisement else { return }
        var txt = advertisement.txtRecord
        txt["players"] = String(1 + peers.count)
        listener.service = NWListener.Service(
            name: advertisement.name,
            type: Self.bonjourServiceType,
            txtRecord: NWTXTRecord(txt)
        )
    }

    /// Host: deliver a client's packet locally and/or relay it to other clients.
    private func route(_ frame: Frame, fromPeer sender: UInt16) {
        let relayed = Frame(kind: .data, from: sender, to: frame.to, payload: frame.payload)
        switch frame.to {
        case Self.hostID:
            onPacket?(frame.payload, sender)
        case NetpacketFlags.broadcastID:
            onPacket?(frame.payload, sender)
            for (clientID, connection) in peers where clientID != sender {
                sendFrame(relayed, on: connection)
            }
        default:
            if frame.to != sender, let connection = peers[frame.to] {
                sendFrame(relayed, on: connection)
            }
        }
    }
}

// MARK: - Client

extension NetpacketTransport {

    private func startClient(host: String, port: UInt16) async throws {
        guard port != 0, let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw NetpacketTransportError.connectionFailed("Invalid port \(port)")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = AtomicOnce()
            let fail: @Sendable (Error) -> Void = { error in
                if once.tryOnce() { continuation.resume(throwing: error) }
            }
            queue.async { [weak self] in
                guard let self, !self.stopped else {
                    fail(NetpacketTransportError.cancelled)
                    return
                }
                let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: endpointPort)
                let connection = NWConnection(to: endpoint, using: Self.tcpParameters())
                self.hostConnection = connection

                connection.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        let hello = Frame(kind: .hello, from: 0, to: Self.hostID,
                                          payload: Self.helloPayload(protocolVersion: self.protocolVersion))
                        self.sendFrame(hello, on: connection)
                        self.receiveFrame(on: connection) { [weak self] frame in
                            guard let self else { return }
                            switch frame?.kind {
                            case .welcome?:
                                guard let frame else { return }
                                self.welcomed = true
                                self.localClientID = frame.to
                                self.onWelcomed?(frame.to)
                                if once.tryOnce() { continuation.resume() }
                                self.receiveLoop(on: connection, peer: Self.hostID)
                            case .reject?:
                                let reason = frame.flatMap { String(bytes: $0.payload, encoding: .utf8) } ?? ""
                                fail(NetpacketTransportError.rejected(reason))
                                connection.cancel()
                            default:
                                fail(NetpacketTransportError.handshakeFailed)
                                connection.cancel()
                            }
                        }
                    case .failed(let error):
                        if self.welcomed {
                            self.endSession(.connectionFailed(error.localizedDescription))
                        } else {
                            fail(NetpacketTransportError.connectionFailed(error.localizedDescription))
                        }
                    case .waiting(let error):
                        // Refused means nobody is listening; give up now. Other
                        // waits (no route yet, the Local Network prompt still
                        // up) are left to the connection and handshake timeouts.
                        if !self.welcomed, case .posix(let code) = error, code == .ECONNREFUSED {
                            fail(NetpacketTransportError.connectionFailed(error.localizedDescription))
                            connection.cancel()
                        }
                    case .cancelled:
                        if self.welcomed {
                            self.endSession(.hostClosed)
                        } else {
                            fail(NetpacketTransportError.cancelled)
                        }
                    default:
                        break
                    }
                }
                connection.start(queue: self.queue)

                self.queue.asyncAfter(deadline: .now() + Self.handshakeTimeout) { [weak self] in
                    guard let self, !self.welcomed else { return }
                    fail(NetpacketTransportError.handshakeFailed)
                    connection.cancel()
                }
            }
        }
    }
}

// MARK: - Wire format

extension NetpacketTransport {
    //
    // Every message is a frame: a 9-byte header followed by `length` bytes.
    //   u32 length | u8 kind | u16 from | u16 to      (big-endian)
    //
    //   hello    client → host   payload: "PVNP" | u16 wire version | protocol version (UTF-8)
    //   welcome  host → client   `to` is the client's assigned ID
    //   reject   host → client   payload: reason (UTF-8)
    //   data     both ways       payload: the core's packet

    enum FrameKind: UInt8 {
        case hello = 1
        case welcome = 2
        case reject = 3
        case data = 4
    }

    struct Frame: Equatable, Sendable {
        var kind: FrameKind
        var from: UInt16
        var to: UInt16
        var payload: Data
    }

    static let headerSize = 9
    static let helloMagic = Data("PVNP".utf8)
    static let wireVersion: UInt16 = 2

    static func encode(_ frame: Frame) -> Data {
        var data = Data(capacity: headerSize + frame.payload.count)
        appendBigEndian(UInt32(frame.payload.count), to: &data)
        data.append(frame.kind.rawValue)
        appendBigEndian(frame.from, to: &data)
        appendBigEndian(frame.to, to: &data)
        data.append(frame.payload)
        return data
    }

    /// Decodes a frame header into (kind, from, to, payload length), or nil
    /// for an unknown kind or an oversized payload.
    static func decodeHeader(_ header: Data) -> (kind: FrameKind, from: UInt16, to: UInt16, length: Int)? {
        guard header.count == headerSize else { return nil }
        let bytes = [UInt8](header)
        let length = Int(bytes[0]) << 24 | Int(bytes[1]) << 16 | Int(bytes[2]) << 8 | Int(bytes[3])
        guard let kind = FrameKind(rawValue: bytes[4]),
              length <= maxPayloadSize + 1024 else {
            return nil
        }
        let from = UInt16(bytes[5]) << 8 | UInt16(bytes[6])
        let to = UInt16(bytes[7]) << 8 | UInt16(bytes[8])
        return (kind, from, to, length)
    }

    static func helloPayload(protocolVersion: String) -> Data {
        var data = helloMagic
        appendBigEndian(wireVersion, to: &data)
        data.append(Data(protocolVersion.utf8))
        return data
    }

    /// The protocol version in a hello payload, or nil if it isn't ours.
    static func protocolVersion(fromHello payload: Data) -> String? {
        guard payload.count >= helloMagic.count + 2,
              payload.prefix(helloMagic.count) == helloMagic else {
            return nil
        }
        let bytes = [UInt8](payload)
        let version = UInt16(bytes[4]) << 8 | UInt16(bytes[5])
        guard version == wireVersion else { return nil }
        return String(bytes: payload.dropFirst(helloMagic.count + 2), encoding: .utf8)
    }

    private static func appendBigEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }
}

// MARK: - Errors

/// Errors specific to `NetpacketTransport`.
public enum NetpacketTransportError: Error, LocalizedError, Sendable, Equatable {
    case cancelled
    case handshakeFailed
    case rejected(String)
    case hostClosed
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Netpacket transport was cancelled."
        case .handshakeFailed:
            return "The host didn't answer as a Provenance netplay host."
        case .rejected(let reason):
            return "The host refused the connection: \(reason)"
        case .hostClosed:
            return "The host ended the session."
        case .connectionFailed(let reason):
            return "Netpacket connection failed: \(reason)"
        }
    }
}

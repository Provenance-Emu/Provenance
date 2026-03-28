/// A full DSU / CemuHook server that broadcasts virtual controller input.
///
/// `DSUSkinServer` listens on UDP port 26760 (the standard DSU port), responds to
/// client handshake messages, and periodically pushes `controllerData` packets to
/// every subscribed client at ~60 Hz.  Input state is updated by calling
/// ``updateButtonState(inputID:pressed:)`` and ``updateAnalogStick(inputID:x:y:)``
/// from the UI layer — typically driven by touch events on a Delta skin overlay.
///
/// ## Typical use
/// ```swift
/// let server = DSUSkinServer()
/// try await server.start()
///
/// // From a touch-event handler:
/// await server.updateButtonState(inputID: "a", pressed: true)
/// await server.updateAnalogStick(inputID: "leftthumbstick", x: 0.5, y: -0.3)
///
/// // Later:
/// await server.stop()
/// ```
///
/// - Note: Network.framework is Apple-only, so this type is unavailable on Linux.

#if canImport(Network)
import Foundation
import Network

// MARK: - NWEndpoint helpers

private extension NWEndpoint {
    /// Extracts host string and port UInt16, or returns `nil` for non-host-port endpoints.
    var hostAndPort: (String, UInt16)? {
        guard case .hostPort(let host, let port) = self else { return nil }
        return (host.debugDescription, port.rawValue)
    }
}

// MARK: - Subscriber

private struct DSUSubscriber: Hashable, Sendable {
    let host: String
    let port: UInt16
    let clientUID: UInt32
    /// Last time this subscriber sent a padDataRequest (used for expiry).
    var lastSeen: ContinuousClock.Instant

    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
    }

    static func == (lhs: DSUSubscriber, rhs: DSUSubscriber) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }
}

// MARK: - DSUSkinServer

/// Actor-isolated DSU server. All state mutations are serialised through the actor.
public actor DSUSkinServer {

    // MARK: - Public state

    /// Whether the server is currently listening for clients.
    public private(set) var isRunning: Bool = false

    /// The UDP port in use. Defaults to ``DSUConstants/defaultPort``.
    public let port: UInt16

    // MARK: - Private state

    private var socket: DSUSocket?
    private var receiveTask: Task<Void, Never>?
    private var broadcastTask: Task<Void, Never>?

    /// Registered DSU subscribers (clients that sent a padDataRequest).
    private var subscribers: Set<DSUSubscriber> = []

    /// The most-recently-set controller data (mutable between input events).
    private var controllerData: DSUControllerData = DSUControllerData()

    /// Monotonically-incrementing packet number stamped on every broadcast.
    private var packetNumber: UInt32 = 0

    // MARK: - Init

    public init(port: UInt16 = DSUConstants.defaultPort) {
        self.port = port
    }

    // MARK: - Lifecycle

    /// Start the DSU server.
    ///
    /// Opens a UDP socket on ``port``, begins Bonjour advertisement, and starts
    /// the receive loop and 60 Hz broadcast loop.
    ///
    /// - Throws: ``DSUSocketError`` if the listener cannot be opened.
    public func start() async throws {
        guard !isRunning else { return }
        let sock = try DSUSocket(port: port)
        await sock.startListening()
        self.socket = sock
        isRunning = true

        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop()
        }

        broadcastTask = Task { [weak self] in
            guard let self else { return }
            await self.broadcastLoop()
        }
    }

    /// Stop the DSU server, cancelling all background tasks and closing the socket.
    public func stop() async {
        guard isRunning else { return }
        receiveTask?.cancel()
        broadcastTask?.cancel()
        receiveTask = nil
        broadcastTask = nil
        await socket?.close()
        socket = nil
        isRunning = false
        subscribers.removeAll()
    }

    // MARK: - Input API

    /// Update the pressed/released state of a skin button.
    ///
    /// - Parameters:
    ///   - inputID: The Delta skin button identifier (e.g. `"a"`, `"l1"`, `"dpad_up"`).
    ///   - pressed: `true` on press, `false` on release.
    public func updateButtonState(inputID: String, pressed: Bool) {
        DSUSkinButtonMapper.apply(inputID: inputID, pressed: pressed, to: &controllerData)
    }

    /// Update an analog stick position from a skin joystick.
    ///
    /// - Parameters:
    ///   - inputID: The skin joystick identifier (e.g. `"leftthumbstick"`).
    ///   - x: Horizontal component in [-1, 1].
    ///   - y: Vertical component in [-1, 1] (positive = up in skin space).
    public func updateAnalogStick(inputID: String, x: Float, y: Float) {
        DSUSkinButtonMapper.applyAnalogStick(inputID: inputID, x: x, y: y, to: &controllerData)
    }

    /// Reset all button state to the neutral/released position.
    public func resetInput() {
        controllerData = DSUControllerData()
    }

    // MARK: - Receive loop

    private func receiveLoop() async {
        guard let socket else { return }
        while !Task.isCancelled {
            guard let (data, endpoint) = try? await socket.receive() else { continue }
            guard let packet = DSUPacket.decode(data) else { continue }
            guard let (host, clientPort) = endpoint.hostAndPort else { continue }
            await handlePacket(packet, from: host, clientPort: clientPort)
        }
    }

    private func handlePacket(_ packet: DSUPacket, from host: String, clientPort: UInt16) async {
        switch packet {
        case .versionRequest(let uid):
            let response = DSUPacket.versionResponse(clientUID: uid, version: DSUConstants.protocolVersion)
            await sendPacket(response, to: host, port: clientPort)

        case .listPortsRequest(let uid, _):
            // We advertise one virtual controller in slot 0.
            let response = DSUPacket.listPortsResponse(
                clientUID: uid,
                slotIndex: 0,
                slotState: .connected,
                deviceModel: .full,
                connectionType: .bluetooth,
                macAddress: virtualMAC,
                batteryStatus: .full
            )
            await sendPacket(response, to: host, port: clientPort)

        case .padDataRequest(let uid, _, _, _):
            // Register (or refresh) this client as a subscriber.
            let subscriber = DSUSubscriber(host: host, port: clientPort, clientUID: uid, lastSeen: .now)
            // Remove any existing entry first (Set.insert is a no-op if an equal element exists,
            // so we must remove to update the mutable lastSeen field).
            subscribers.remove(subscriber)
            subscribers.insert(subscriber)

        default:
            break
        }
    }

    // MARK: - Broadcast loop

    private func broadcastLoop() async {
        // Target: 60 Hz = ~16.67 ms per frame.
        while !Task.isCancelled {
            await broadcast()
            try? await Task.sleep(for: .microseconds(16_667))
        }
    }

    /// Subscribers that have not sent a padDataRequest within this interval are dropped.
    private static let subscriberTTL: Duration = .seconds(10)

    private func broadcast() async {
        guard !subscribers.isEmpty, let socket else { return }

        // Expire stale subscribers — DSU clients must re-register periodically.
        let expiryCutoff = ContinuousClock.now - DSUSkinServer.subscriberTTL
        subscribers = subscribers.filter { $0.lastSeen >= expiryCutoff }

        guard !subscribers.isEmpty else { return }
        packetNumber &+= 1
        var snapshot = controllerData
        snapshot.packetNumber = packetNumber

        for subscriber in subscribers {
            let packet = DSUPacket.controllerData(clientUID: subscriber.clientUID, data: snapshot)
            await sendPacket(packet, to: subscriber.host, port: subscriber.port)
        }
    }

    // MARK: - Helpers

    private func sendPacket(_ packet: DSUPacket, to host: String, port: UInt16) async {
        guard let socket else { return }
        let data = packet.encode()
        try? await socket.send(data, to: host, port: port)
    }

    /// A deterministic fake MAC address that identifies this virtual controller.
    private let virtualMAC: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01)
}

#endif // canImport(Network)

/// Async/await wrapper around `NWListener` + `NWConnection` for DSU UDP transport.
///
/// Not available on Linux (Network.framework is Apple-only).

#if canImport(Network)
import Network
import Foundation

// MARK: - Errors

/// Errors thrown by DSU socket operations.
public enum DSUSocketError: Error, Sendable {
    case listenerFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case closed
}

// MARK: - DSUSocket

/// An actor that owns a UDP listener and dispatches received packets.
///
/// Usage:
/// ```swift
/// let socket = try DSUSocket(port: 26760)
/// Task {
///     while true {
///         let (data, endpoint) = try await socket.receive()
///         // handle packet...
///     }
/// }
/// // Send a response
/// try await socket.send(responseData, to: "192.168.1.5", port: 26760)
/// ```
public actor DSUSocket {

    // MARK: - Private state

    private let listener: NWListener
    private var connections: [NWEndpoint: NWConnection] = [:]
    private var receiveQueue: [ReceiveItem] = []
    private var waiters: [CheckedContinuation<ReceiveItem, Error>] = []
    private var isClosed: Bool = false

    private typealias ReceiveItem = (Data, NWEndpoint)

    // MARK: - Init

    /// Create a UDP listener bound to the given port.
    ///
    /// - Parameter port: The local UDP port to listen on (default 26760).
    /// - Throws: `DSUSocketError.listenerFailed` if the listener cannot be created.
    public init(port: UInt16 = DSUConstants.defaultPort) throws {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw DSUSocketError.listenerFailed("Invalid port: \(port)")
        }

        self.listener = try NWListener(using: params, on: nwPort)
        // Note: listener.start() is deferred to startListening() so that the
        // newConnectionHandler is always installed before the listener begins
        // accepting connections — avoids a race where early datagrams are dropped.
    }

    // MARK: - Start (must be called after init, from within actor context)

    /// Begin accepting incoming UDP connections/datagrams.
    ///
    /// Call this once after initialisation. Sets the new-connection handler and
    /// then starts the listener so no connections are missed.
    public func startListening() {
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task {
                await self.handleNewConnection(connection)
            }
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - Send

    /// Send a datagram to the specified host and port.
    ///
    /// A short-lived `NWConnection` is reused if one already exists for the endpoint.
    ///
    /// - Parameters:
    ///   - data: The bytes to send.
    ///   - host: Destination hostname or IP string.
    ///   - port: Destination UDP port.
    public func send(_ data: Data, to host: String, port: UInt16) async throws {
        guard !isClosed else { throw DSUSocketError.closed }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: DSUConstants.defaultPort)!
        )

        let connection = connectionForEndpoint(endpoint)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: DSUSocketError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Receive

    /// Await the next received datagram.
    ///
    /// Returned values are delivered in FIFO order. Suspends if no data is available yet.
    ///
    /// - Returns: A tuple of the raw bytes and the sender's endpoint.
    public func receive() async throws -> (Data, NWEndpoint) {
        guard !isClosed else { throw DSUSocketError.closed }

        if let item = receiveQueue.first {
            receiveQueue.removeFirst()
            return item
        }

        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    // MARK: - Close

    /// Cancel the listener and all managed connections.
    public func close() {
        isClosed = true
        listener.cancel()
        for conn in connections.values {
            conn.cancel()
        }
        connections.removeAll()
        // Resume any pending waiters with an error
        for waiter in waiters {
            waiter.resume(throwing: DSUSocketError.closed)
        }
        waiters.removeAll()
    }

    // MARK: - Private helpers

    private func handleNewConnection(_ connection: NWConnection) {
        let endpoint = connection.endpoint
        connections[endpoint] = connection
        connection.start(queue: .global(qos: .userInitiated))
        scheduleReceive(on: connection)
    }

    private func scheduleReceive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                let endpoint = connection.endpoint
                Task {
                    await self.deliverData(data, from: endpoint)
                }
            }
            if error == nil {
                // Re-schedule from the actor context to satisfy Swift 6 isolation.
                Task { [weak self] in
                    await self?.scheduleReceive(on: connection)
                }
            }
        }
    }

    private func deliverData(_ data: Data, from endpoint: NWEndpoint) {
        if waiters.isEmpty {
            receiveQueue.append((data, endpoint))
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume(returning: (data, endpoint))
        }
    }

    private func connectionForEndpoint(_ endpoint: NWEndpoint) -> NWConnection {
        if let existing = connections[endpoint] {
            return existing
        }
        let params = NWParameters.udp
        let connection = NWConnection(to: endpoint, using: params)
        connections[endpoint] = connection
        connection.start(queue: .global(qos: .userInitiated))
        return connection
    }
}

#endif // canImport(Network)

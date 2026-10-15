//
//  LibraryHTTPListener.swift
//  PVLibrarySharing
//
//  One HTTP/1.1 listener per advertised dialect (spec §4).
//

import Foundation

#if canImport(Network) && !os(watchOS)
import Network
import PVLogging

/// A small HTTP/1.1 server on `NWListener`, built for the sharing routes and
/// not on Hummingbird (the spec's first idea), because it needs things a
/// general server hides:
///
/// - one listener and port per dialect, each with its own handler;
/// - `prohibitedInterfaceTypes = [.cellular]` and peer-to-peer Wi-Fi;
/// - the remote address of every connection, for `LANFilter`;
/// - file bodies streamed from disk with back-pressure.
///
/// Requests on one connection are served in order (keep-alive), bodies are
/// `Content-Length` only, and a refused peer's connection is just closed.
public final class LibraryHTTPListener: @unchecked Sendable {
    /// The first port tried; the next free one is taken when it is busy.
    public static let defaultFirstPort: UInt16 = 8484
    static let portAttempts: UInt16 = 32
    /// File bodies go out in chunks of this size, each send awaited.
    static let fileChunkBytes = 256 * 1024
    /// An idle keep-alive connection is closed after this long.
    static let idleTimeout: TimeInterval = 30

    public let name: String
    private let handler: ServerRequestHandler
    private let interfaces: @Sendable () -> [LocalInterfaceAddress]
    private let queue: DispatchQueue
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    public private(set) var port: UInt16?

    /// - Parameters:
    ///   - name: For logs ("iFly dialect").
    ///   - interfaces: The LAN filter's interface list, read per connection so
    ///     a network change applies at once. Tests pass a fixed list.
    public init(
        name: String,
        interfaces: @escaping @Sendable () -> [LocalInterfaceAddress] = { LANFilter.currentInterfaces() },
        handler: @escaping ServerRequestHandler
    ) {
        self.name = name
        self.handler = handler
        self.interfaces = interfaces
        self.queue = DispatchQueue(label: "org.provenance-emu.library-sharing.listener.\(name)")
    }

    deinit {
        listener?.cancel()
        connections.values.forEach { $0.cancel() }
    }

    /// Binds the first free port at or after `firstPort` and starts serving.
    @discardableResult
    public func start(firstPort: UInt16 = LibraryHTTPListener.defaultFirstPort) async throws -> UInt16 {
        var lastError: Error?
        for offset in 0..<Self.portAttempts {
            let candidate = firstPort &+ offset
            guard let port = NWEndpoint.Port(rawValue: candidate) else { continue }
            do {
                try await bind(port)
                return candidate
            } catch {
                lastError = error
            }
        }
        throw lastError ?? LibrarySharingError.unreachable
    }

    public func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
            port = nil
            connections.values.forEach { $0.cancel() }
            connections.removeAll()
        }
    }

    // MARK: - Listener

    private func bind(_ port: NWEndpoint.Port) async throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: port)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Every touch of `resumed` happens on `queue`, where the handler runs.
            nonisolated(unsafe) var resumed = false
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                switch state {
                case .ready:
                    guard !resumed else { return }
                    resumed = true
                    self?.listener = listener
                    self?.port = port.rawValue
                    continuation.resume()
                case .failed(let error), .waiting(let error):
                    guard !resumed else {
                        if case .failed = state { WLOG("Library sharing: \(self?.name ?? "") listener failed: \(error)") }
                        return
                    }
                    resumed = true
                    listener?.cancel()
                    continuation.resume(throwing: error)
                default:
                    return
                }
            }
            listener.start(queue: queue)
        }
    }

    // MARK: - Connections (queue-confined)

    private func accept(_ connection: NWConnection) {
        guard let remote = Self.remoteAddress(of: connection), LANFilter.isAllowed(remote, interfaces: interfaces()) else {
            DLOG("Library sharing: \(name) refused \(connection.endpoint)")
            connection.cancel()
            return
        }
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.connections[id] = nil
            default:
                break
            }
        }
        connection.start(queue: queue)
        readRequest(on: connection, buffer: Data())
    }

    private static func remoteAddress(of connection: NWConnection) -> IPAddressBytes? {
        guard case let .hostPort(host, _) = connection.endpoint else { return nil }
        switch host {
        case .ipv4(let address): return IPAddressBytes(Array(address.rawValue))
        case .ipv6(let address): return IPAddressBytes(Array(address.rawValue))
        case .name(let name, _): return IPAddressBytes(string: name)
        @unknown default: return nil
        }
    }

    /// Reads until a full head (and its body) is buffered, then serves it.
    private func readRequest(on connection: NWConnection, buffer: Data) {
        if let range = buffer.range(of: HTTP1.headTerminator) {
            let headData = buffer[buffer.startIndex..<range.lowerBound]
            let rest = buffer[range.upperBound...]
            do {
                let head = try HTTP1.parseHead(Data(headData))
                readBody(on: connection, head: head, buffer: Data(rest))
            } catch let error as HTTP1.ParseError {
                let status: Int
                switch error {
                case .headTooLarge: status = 431
                case .bodyTooLarge: status = 413
                case .malformed, .unsupportedTransferEncoding: status = 400
                }
                send(.error(status, "bad request"), on: connection, keepAlive: false)
            } catch {
                connection.cancel()
            }
            return
        }
        guard buffer.count <= HTTP1.maxHeadBytes else {
            send(.error(431, "request head too large"), on: connection, keepAlive: false)
            return
        }
        receive(on: connection) { [weak self] data in
            self?.readRequest(on: connection, buffer: buffer + data)
        }
    }

    private func readBody(on connection: NWConnection, head: HTTP1.Head, buffer: Data) {
        let needed = head.contentLength
        if buffer.count >= needed {
            let body = needed > 0 ? Data(buffer.prefix(needed)) : nil
            let leftover = Data(buffer.dropFirst(needed))
            let request = HTTP1.request(head: head, body: body, remoteAddress: "\(connection.endpoint)")
            let handler = handler
            Task { [weak self] in
                let response = await handler(request)
                guard let self else { return }
                self.queue.async {
                    self.send(response, on: connection, keepAlive: head.keepAlive) { [weak self] in
                        self?.readRequest(on: connection, buffer: leftover)
                    }
                }
            }
            return
        }
        receive(on: connection) { [weak self] data in
            self?.readBody(on: connection, head: head, buffer: buffer + data)
        }
    }

    private func receive(on connection: NWConnection, then: @escaping (Data) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                then(data)
            } else if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    // MARK: - Responses

    private func send(_ response: ServerResponse, on connection: NWConnection, keepAlive: Bool, next: (() -> Void)? = nil) {
        let finish: (NWError?) -> Void = { error in
            if error != nil || !keepAlive {
                connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } else {
                next?()
            }
        }
        switch response.body {
        case .data(let data):
            let head = HTTP1.responseHead(response, contentLength: Int64(data.count), keepAlive: keepAlive)
            connection.send(content: head + data, completion: .contentProcessed(finish))
        case let .file(url, offset, length):
            guard let handle = try? FileHandle(forReadingFrom: url) else {
                send(.error(404, "file unavailable"), on: connection, keepAlive: keepAlive, next: next)
                return
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            let total = max(0, length ?? (size - offset))
            do {
                try handle.seek(toOffset: UInt64(offset))
            } catch {
                try? handle.close()
                send(.error(416, "range not satisfiable"), on: connection, keepAlive: keepAlive, next: next)
                return
            }
            let head = HTTP1.responseHead(response, contentLength: total, keepAlive: keepAlive)
            connection.send(content: head, completion: .contentProcessed { [weak self] error in
                guard error == nil else {
                    try? handle.close()
                    finish(error)
                    return
                }
                self?.streamFile(handle, remaining: total, on: connection) { error in
                    try? handle.close()
                    finish(error)
                }
            })
        }
    }

    /// Sends `remaining` bytes from `handle`, one chunk per completed send.
    private func streamFile(_ handle: FileHandle, remaining: Int64, on connection: NWConnection, done: @escaping (NWError?) -> Void) {
        guard remaining > 0 else {
            done(nil)
            return
        }
        let count = Int(min(Int64(Self.fileChunkBytes), remaining))
        guard let chunk = try? handle.read(upToCount: count), !chunk.isEmpty else {
            // The file shrank under us; the Content-Length promise can't be kept.
            done(.posix(.EIO))
            return
        }
        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                done(error)
                return
            }
            self?.streamFile(handle, remaining: remaining - Int64(chunk.count), on: connection, done: done)
        })
    }
}
#endif

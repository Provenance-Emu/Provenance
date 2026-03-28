/// Bonjour/mDNS advertisement and discovery for the DSU protocol.
///
/// The service type used is `_provenance-dsu._udp.`
///
/// Not available on Linux (Network.framework is Apple-only).

#if canImport(Network)
import Network
import Foundation

/// Bonjour service type for the Provenance DSU server.
public let DSUBonjourServiceType = "_provenance-dsu._udp."

// MARK: - DSUServiceAdvertiser

/// Advertises a Provenance DSU server over mDNS/Bonjour.
///
/// Thread-safe: `start()` and `stop()` may be called from any thread.
///
/// ```swift
/// let advertiser = DSUServiceAdvertiser(port: 26760, name: "My Provenance")
/// advertiser.start()
/// // …
/// advertiser.stop()
/// ```
public final class DSUServiceAdvertiser: @unchecked Sendable {

    // MARK: - Private state

    private let port: UInt16
    private let serviceName: String
    /// Serialises all reads/writes of `listener` and `isStopped`.
    private let queue = DispatchQueue(label: "com.provenance.dsu.advertiser", qos: .utility)
    private var listener: NWListener?
    private var isStopped = false

    // MARK: - Init

    /// Create a new advertiser.
    ///
    /// - Parameters:
    ///   - port: The UDP port on which the DSU server is listening (default 26760).
    ///   - name: The human-readable Bonjour service name (default "Provenance DSU").
    public init(port: UInt16 = DSUConstants.defaultPort, name: String = "Provenance DSU") {
        self.port = port
        self.serviceName = name
    }

    // MARK: - Public API

    /// Begin advertising the DSU service via Bonjour.
    ///
    /// Safe to call from any thread. A no-op if already started.
    public func start() {
        queue.async { [weak self] in
            guard let self, !self.isStopped else { return }
            self.startOnQueue()
        }
    }

    /// Stop advertising the DSU service.
    ///
    /// Safe to call from any thread. Cancels any pending retry.
    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isStopped = true
            self.listener?.cancel()
            self.listener = nil
        }
    }

    // MARK: - Private (called only from self.queue)

    private func startOnQueue() {
        let params = NWParameters.udp
        params.includePeerToPeer = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            let listener = try NWListener(using: params, on: nwPort)
            listener.service = NWListener.Service(name: serviceName, type: DSUBonjourServiceType)

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                if case .failed = state {
                    // Retry after a short delay, but only if not stopped.
                    self.queue.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self, !self.isStopped else { return }
                        self.startOnQueue()
                    }
                }
            }

            listener.newConnectionHandler = { connection in
                // DSU is connectionless UDP; reject any unexpected TCP connections.
                connection.cancel()
            }

            listener.start(queue: queue)
            self.listener = listener
        } catch {
            // Listener creation can fail if the port is already in use; silently ignore.
        }
    }
}

// MARK: - DSUServiceBrowser

/// Browses for Provenance DSU servers on the local network using Bonjour/mDNS.
///
/// Thread-safe: `start()` and `stop()` may be called from any thread.
///
/// ```swift
/// let browser = DSUServiceBrowser { result in
///     print("Found: \(result)")
/// }
/// browser.start()
/// // …
/// browser.stop()
/// ```
public final class DSUServiceBrowser: @unchecked Sendable {

    // MARK: - Public typealiases

    /// Called whenever a browse result is added or removed.
    public typealias FoundHandler = @Sendable (NWBrowser.Result) -> Void

    // MARK: - Private state

    /// Serialises all reads/writes of `browser` and `isStopped`.
    private let queue = DispatchQueue(label: "com.provenance.dsu.browser", qos: .utility)
    private var browser: NWBrowser?
    private let foundHandler: FoundHandler
    private var isStopped = false

    // MARK: - Init

    /// Create a browser that notifies the caller about discovered services.
    ///
    /// - Parameter found: A closure called on each browse result (add/remove/change).
    ///   The closure is invoked on an internal serial queue; dispatch to main if needed.
    public init(found: @escaping FoundHandler) {
        self.foundHandler = found
    }

    // MARK: - Public API

    /// Start browsing for DSU servers on the local network.
    ///
    /// Safe to call from any thread. A no-op if already started.
    public func start() {
        queue.async { [weak self] in
            guard let self, !self.isStopped else { return }
            self.startOnQueue()
        }
    }

    /// Stop browsing for DSU servers.
    ///
    /// Safe to call from any thread. Cancels any pending retry.
    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isStopped = true
            self.browser?.cancel()
            self.browser = nil
        }
    }

    // MARK: - Private (called only from self.queue)

    private func startOnQueue() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: DSUBonjourServiceType, domain: "local.")
        let params = NWParameters.udp
        params.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: params)

        browser.browseResultsChangedHandler = { [weak self] _, changes in
            guard let self else { return }
            for change in changes {
                if case .added(let result) = change {
                    self.foundHandler(result)
                }
            }
        }

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .failed = state {
                // Retry browsing after a delay, but only if not stopped.
                self.queue.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self, !self.isStopped else { return }
                    self.startOnQueue()
                }
            }
        }

        browser.start(queue: queue)
        self.browser = browser
    }
}

#endif // canImport(Network)

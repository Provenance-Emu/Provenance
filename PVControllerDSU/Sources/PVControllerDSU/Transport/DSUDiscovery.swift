/// Bonjour/mDNS advertisement and discovery for the DSU protocol.
///
/// The service type used is `_provenance-dsu._udp.`
///
/// Not available on Linux (Network.framework is Apple-only).

#if canImport(Network)
import Network
import Foundation

// MARK: - DSUServiceAdvertiser

/// Advertises a Provenance DSU server over mDNS/Bonjour.
///
/// Thread-safe: `start()` and `stop()` may be called from any thread.
///
/// **Port sharing:** The advertiser binds to the same UDP port as the DSU server
/// so that it can publish the Bonjour record. If you also run a `DSUSocket` on
/// the same port, both objects set `allowLocalEndpointReuse = true`, which
/// permits multiple sockets to share a port. Incoming datagrams will be routed
/// to the `DSUSocket`; the advertiser's listener discards any that arrive at its
/// own connection handler.
///
/// - Note: On **watchOS**, Bonjour advertisement requires the app to hold a network
///   connection open (e.g., an `NWConnection`). Advertisement may be restricted when
///   the app is in the background.
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
    /// Safe to call from any thread. A no-op if already started or stopped.
    public func start() {
        queue.async { [weak self] in
            guard let self, !self.isStopped, self.listener == nil else { return }
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
        // Required so the advertiser can co-exist on the same port as DSUSocket.
        params.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            let listener = try NWListener(using: params, on: nwPort)
            listener.service = NWListener.Service(name: serviceName, type: DSUConstants.bonjourServiceType)

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
                // The advertiser listener is for Bonjour registration only.
                // Any datagrams that arrive here are discarded; actual packet
                // handling is done by DSUSocket on the same port.
                connection.cancel()
            }

            listener.start(queue: queue)
            self.listener = listener
        } catch {
            // Listener creation can fail if the port is already in use; silently ignore.
        }
    }
}

// MARK: - DSUBrowserChange

/// Describes a change to the set of discovered DSU servers.
public enum DSUBrowserChange: Sendable {
    /// A new DSU server appeared on the network.
    case added(NWBrowser.Result)
    /// A previously discovered DSU server is no longer reachable.
    case removed(NWBrowser.Result)
}

// MARK: - DSUServiceBrowser

/// Browses for Provenance DSU servers on the local network using Bonjour/mDNS.
///
/// Thread-safe: `start()` and `stop()` may be called from any thread.
///
/// The `changeHandler` is called for both `.added` (server appeared) and
/// `.removed` (server went offline) events.
///
/// - Note: On **watchOS** and **tvOS**, Bonjour browsing works but the discovered
///   endpoint must be resolved (via `NWConnection`) before connecting. Background
///   browsing may be limited by the OS on watchOS.
///
/// ```swift
/// let browser = DSUServiceBrowser { change in
///     switch change {
///     case .added(let result):   print("Found: \(result)")
///     case .removed(let result): print("Lost: \(result)")
///     }
/// }
/// browser.start()
/// // …
/// browser.stop()
/// ```
public final class DSUServiceBrowser: @unchecked Sendable {

    // MARK: - Public typealiases

    /// Called whenever a DSU server is added to or removed from the local network.
    /// Invoked on an internal serial queue; dispatch to main if needed for UI updates.
    public typealias ChangeHandler = @Sendable (DSUBrowserChange) -> Void

    // MARK: - Private state

    /// Serialises all reads/writes of `browser` and `isStopped`.
    private let queue = DispatchQueue(label: "com.provenance.dsu.browser", qos: .utility)
    private var browser: NWBrowser?
    private let changeHandler: ChangeHandler
    private var isStopped = false

    // MARK: - Init

    /// Create a browser that notifies the caller about discovered and removed services.
    ///
    /// - Parameter change: A closure called for each `.added` or `.removed` event.
    ///   Invoked on an internal serial queue; dispatch to main for UI updates.
    public init(change: @escaping ChangeHandler) {
        self.changeHandler = change
    }

    // MARK: - Public API

    /// Start browsing for DSU servers on the local network.
    ///
    /// Safe to call from any thread. A no-op if already started or stopped.
    public func start() {
        queue.async { [weak self] in
            guard let self, !self.isStopped, self.browser == nil else { return }
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
        let descriptor = NWBrowser.Descriptor.bonjour(type: DSUConstants.bonjourServiceType, domain: "local.")
        let params = NWParameters.udp
        params.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: params)

        browser.browseResultsChangedHandler = { [weak self] _, changes in
            guard let self else { return }
            for change in changes {
                switch change {
                case .added(let result):
                    self.changeHandler(.added(result))
                case .removed(let result):
                    self.changeHandler(.removed(result))
                default:
                    break
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

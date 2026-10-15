//
//  PeerBrowser.swift
//  PVLibrarySharing
//
//  Bonjour discovery of iFly and iCube libraries.
//

import Foundation

/// The state of one service type's browse. A failure is reported, never
/// swallowed: an empty list must be distinguishable from "nothing found".
public enum PeerBrowseState: Sendable, Equatable {
    case idle
    case browsing
    /// Network.framework is waiting, e.g. Local Network access was denied.
    case waiting(reason: String, localNetworkDenied: Bool)
    /// The browse failed outright. For `_icube-continuity._tcp`, whose
    /// 16-character name is over the RFC 6335 limit, this is the failure the
    /// spec asks us to watch for on device.
    case failed(reason: String)
}

/// Everything the browser knows at one moment.
public struct PeerBrowserSnapshot: Sendable, Equatable {
    public var peers: [DiscoveredPeer]
    public var states: [PeerApp: PeerBrowseState]

    public init(peers: [DiscoveredPeer] = [], states: [PeerApp: PeerBrowseState] = [:]) {
        self.peers = peers
        self.states = states
    }

    /// True when some service type's browse is blocked by Local Network
    /// permission: the UI should point at Settings › Privacy.
    public var localNetworkDenied: Bool {
        states.values.contains {
            if case .waiting(_, true) = $0 { return true }
            return false
        }
    }
}

#if canImport(Network) && !os(watchOS)
import Network
import PVLogging

/// Browses every `PeerApp` service type with `NWBrowser` and streams
/// de-duplicated `lib=1` peers plus each type's browse state.
///
/// Each type must be listed in the app's `NSBonjourServices`, or the browse
/// finds nothing on iOS 14+.
public final class PeerBrowser: @unchecked Sendable {
    /// `kDNSServiceErr_PolicyDenied`: Local Network permission was refused.
    private static let policyDeniedCode: Int32 = -65570

    public let apps: [PeerApp]

    // All mutable state is confined to `queue`.
    private let queue = DispatchQueue(label: "org.provenance-emu.library-sharing.browser")
    private var browsers: [PeerApp: NWBrowser] = [:]
    private var peersByApp: [PeerApp: [DiscoveredPeer]] = [:]
    private var states: [PeerApp: PeerBrowseState] = [:]
    private var continuation: AsyncStream<PeerBrowserSnapshot>.Continuation?
    /// Bumped per `snapshots()` call so ending an old stream can't stop a newer browse.
    private var generation = 0

    public init(apps: [PeerApp] = PeerApp.allCases) {
        self.apps = apps
    }

    deinit {
        browsers.values.forEach { $0.cancel() }
        continuation?.finish()
    }

    /// Starts browsing (restarting any earlier browse) and streams snapshots.
    public func snapshots() -> AsyncStream<PeerBrowserSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: PeerBrowserSnapshot.self)
        queue.async { [self] in
            stopLocked()
            generation += 1
            let current = generation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    if self.generation == current { self.stopLocked() }
                }
            }
            self.continuation = continuation
            for app in apps {
                startLocked(app)
            }
            publishLocked()
        }
        return stream
    }

    public func stop() {
        queue.async { [self] in stopLocked() }
    }

    // MARK: - Queue-confined

    private func startLocked(_ app: PeerApp) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: app.serviceType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            self?.handle(state: state, for: app)
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handle(results: results, for: app)
        }
        states[app] = .browsing
        browsers[app] = browser
        browser.start(queue: queue)
    }

    private func stopLocked() {
        browsers.values.forEach { $0.cancel() }
        browsers.removeAll()
        peersByApp.removeAll()
        states.removeAll()
        let finished = continuation
        continuation = nil
        finished?.finish()
    }

    private func handle(state: NWBrowser.State, for app: PeerApp) {
        switch state {
        case .ready:
            states[app] = .browsing
        case .waiting(let error):
            let denied = Self.isPolicyDenied(error)
            WLOG("Nearby Libraries: \(app.serviceType) browse waiting: \(error)\(denied ? " (Local Network denied)" : "")")
            states[app] = .waiting(reason: "\(error)", localNetworkDenied: denied)
        case .failed(let error):
            ELOG("Nearby Libraries: \(app.serviceType) browse failed: \(error)")
            states[app] = .failed(reason: "\(error)")
        case .cancelled, .setup:
            return
        @unknown default:
            return
        }
        publishLocked()
    }

    private func handle(results: Set<NWBrowser.Result>, for app: PeerApp) {
        peersByApp[app] = results.compactMap { result in
            guard case let .service(name, type, _, _) = result.endpoint,
                  case let .bonjour(txt) = result.metadata else { return nil }
            return DiscoveredPeer.make(serviceType: type, serviceName: name, txt: txt.dictionary)
        }
        DLOG("Nearby Libraries: \(app.serviceType) has \(peersByApp[app]?.count ?? 0) library peer(s) of \(results.count) result(s)")
        publishLocked()
    }

    private func publishLocked() {
        let peers = DiscoveredPeer.deduplicated(apps.flatMap { peersByApp[$0] ?? [] })
        continuation?.yield(PeerBrowserSnapshot(peers: peers, states: states))
    }

    private static func isPolicyDenied(_ error: NWError) -> Bool {
        if case let .dns(code) = error { return code == policyDeniedCode }
        return false
    }
}
#endif

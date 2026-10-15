//
//  LibrarySharingHost.swift
//  PVLibrarySharing
//
//  "Share this library": the listeners and adverts (spec §4).
//

import Foundation
import PVSystems

/// A dialect Provenance serves and the Bonjour type it is advertised under.
public enum ServedDialect: String, CaseIterable, Sendable {
    case iFly
    case iCube

    public var serviceType: String {
        switch self {
        case .iFly: return PeerApp.iFly.serviceType
        case .iCube: return PeerApp.iCube.serviceType
        }
    }

    var app: PeerApp {
        switch self {
        case .iFly: return .iFly
        case .iCube: return .iCube
        }
    }

    /// Published only while the shared library holds one of these systems, so
    /// an iFly user never sees a Provenance that has nothing for iFly.
    public var systems: Set<SystemIdentifier> { SystemMap.systems(servedBy: app) }
}

/// The TXT record of a library advert, in the codec both peers decode
/// (`ContinuityTXTRecord`): `v`, a fresh `sid`, `lib=1`, `pid`, `u0..u3`.
/// `tok` is never published.
public enum LibraryAdvertTXT {
    public static func record(peerId: String, urls: [URL], sessionId: String = UUID().uuidString) -> [String: String] {
        var txt = ["v": "1", "sid": sessionId, "lib": "1", "pid": peerId]
        for (index, url) in urls.prefix(PeerAdvertisement.maxURLCandidates).enumerated() {
            txt["u\(index)"] = url.absoluteString
        }
        return txt
    }
}

#if canImport(Network) && !os(watchOS)
import PVLogging

/// Runs Provenance's side of library sharing while "Share this library" is on.
///
/// Each dialect gets its own `LibraryHTTPListener` (the same paths mean
/// different things to iFly and iCube, so one listener can't serve both) on
/// the first free port from 8484, and its own advert. Turning sharing off
/// stops the listeners, withdraws the adverts and drops every token.
public actor LibrarySharingHost {
    public let identity: PeerIdentity
    private let device: HostDevice
    private let library: any SharedLibraryProviding
    private let iFly: IFlyDialectServer
    private let iCube: ICubeDialectServer
    private let sharing = SharingFlag()

    private var listeners: [ServedDialect: LibraryHTTPListener] = [:]
    private var advertisers: [ServedDialect: BonjourAdvertiser] = [:]

    public init(
        identity: PeerIdentity,
        device: HostDevice,
        library: any SharedLibraryProviding,
        trust: any HostTrustStore,
        approver: any LibraryHostApproving,
        hashes: FileHashCache
    ) {
        self.identity = identity
        self.device = device
        self.library = library
        let flag = sharing
        let enabled: @Sendable () async -> Bool = { flag.value }
        iFly = IFlyDialectServer(
            identity: identity, device: device, library: library, trust: trust,
            approver: approver, hashes: hashes, sharingEnabled: enabled
        )
        iCube = ICubeDialectServer(
            identity: identity, device: device, library: library, trust: trust,
            approver: approver, hashes: hashes, sharingEnabled: enabled
        )
    }

    public var isRunning: Bool { sharing.value }

    /// The bound port per dialect, while running.
    public var ports: [ServedDialect: UInt16] {
        listeners.compactMapValues(\.port)
    }

    /// Starts every dialect's listener and publishes the adverts that apply.
    public func start() async throws {
        guard !sharing.value else { return }
        sharing.value = true
        do {
            for dialect in ServedDialect.allCases {
                let listener = LibraryHTTPListener(name: dialect.rawValue, handler: handler(for: dialect))
                try await listener.start(firstPort: (listeners.values.compactMap(\.port).max() ?? LibraryHTTPListener.defaultFirstPort - 1) + 1)
                listeners[dialect] = listener
            }
        } catch {
            await stop()
            throw error
        }
        await refreshAdvertisements()
    }

    public func stop() async {
        sharing.value = false
        listeners.values.forEach { $0.stop() }
        listeners.removeAll()
        for advertiser in advertisers.values { await advertiser.withdraw() }
        advertisers.removeAll()
        await iFly.revokeAll()
        await iCube.revokeAll()
    }

    /// Re-reads the shared library and publishes or withdraws each dialect's
    /// advert. Call after an import, a deletion or a sharing-settings change.
    public func refreshAdvertisements() async {
        guard sharing.value else { return }
        let systems = Set(await library.sharedGames().map(\.system))
        for dialect in ServedDialect.allCases {
            let wanted = !dialect.systems.isDisjoint(with: systems)
            if wanted, advertisers[dialect] == nil, let port = listeners[dialect]?.port {
                let advertiser = BonjourAdvertiser(type: dialect.serviceType, name: "Provenance \(device.name)", port: port)
                await advertiser.publish(txt: LibraryAdvertTXT.record(peerId: identity.id, urls: LANFilter.baseURLs(port: port)))
                advertisers[dialect] = advertiser
            } else if !wanted, let advertiser = advertisers.removeValue(forKey: dialect) {
                await advertiser.withdraw()
            }
        }
    }

    /// Forgets one peer's tokens (removed from Trusted Devices).
    public func revoke(peerId: String) async {
        await iFly.revoke(peerId: peerId)
        await iCube.revoke(peerId: peerId)
    }

    private func handler(for dialect: ServedDialect) -> ServerRequestHandler {
        switch dialect {
        case .iFly:
            let server = iFly
            return { await server.handle($0) }
        case .iCube:
            let server = iCube
            return { await server.handle($0) }
        }
    }
}

/// Read per request, so turning sharing off takes effect at once.
final class SharingFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false

    var value: Bool {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// One `NetService` advert. NetService, not `NWListener.service`, because
/// `_icube-continuity._tcp` is 16 characters, over RFC 6335's 15, and iCube
/// itself publishes it with NetService. It must be scheduled on the main run
/// loop or it silently never publishes.
@MainActor
final class BonjourAdvertiser {
    private let type: String
    private let name: String
    private let port: UInt16
    private var service: NetService?
    private var delegate: AdvertiserDelegate?

    nonisolated init(type: String, name: String, port: UInt16) {
        self.type = type
        self.name = name
        self.port = port
    }

    func publish(txt: [String: String]) {
        let service = NetService(domain: "local.", type: type, name: name, port: Int32(port))
        let delegate = AdvertiserDelegate()
        self.service = service
        self.delegate = delegate
        service.delegate = delegate
        service.setTXTRecord(NetService.data(fromTXTRecord: txt.mapValues { Data($0.utf8) }))
        service.includesPeerToPeer = true
        service.schedule(in: .main, forMode: .common)
        service.publish()
    }

    func withdraw() {
        service?.stop()
        service = nil
    }
}

private final class AdvertiserDelegate: NSObject, NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        ILOG("Library sharing: published \(sender.type) as \"\(sender.name)\" on port \(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        ELOG("Library sharing: couldn't publish \(sender.type): \(errorDict)")
    }
}
#endif

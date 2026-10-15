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
    /// v1.1 `_pvlibrary._tcp`: every shared system, published whenever sharing is on.
    case pvLibrary

    public var serviceType: String { app.serviceType }

    var app: PeerApp {
        switch self {
        case .iFly: return .iFly
        case .iCube: return .iCube
        case .pvLibrary: return .pvLibrary
        }
    }

    /// The legacy types are published only while the shared library holds one
    /// of their systems, so an iFly user never sees a Provenance that has
    /// nothing for iFly. `_pvlibrary` serves everything.
    public var systems: Set<SystemIdentifier> { SystemMap.systems(servedBy: app) }

    var alwaysPublished: Bool { self == .pvLibrary }
}

/// The TXT record of a library advert, in the codec both peers decode
/// (`ContinuityTXTRecord`): `v=1`, a fresh `sid`, `lib=1`, `pid`, `u0..u3`.
/// `tok` and the per-game keys are never published, so neither peer mistakes
/// it for a handoff. v1.1 keys ride along (old peers ignore them): `app`,
/// `lx`, `sys`/`sys1`… and `cv`.
public enum LibraryAdvertTXT {
    /// The most bytes one `sys*` value may hold.
    public static let maxSystemsBytes = 240

    public static func record(
        peerId: String,
        urls: [URL],
        systems: Set<SystemIdentifier>? = nil,
        catalogueVersion: String? = nil,
        sessionId: String = UUID().uuidString
    ) -> [String: String] {
        var txt = ["v": "1", "sid": sessionId, "lib": "1", "pid": peerId, "app": "provenance", "lx": "1"]
        for (index, url) in urls.prefix(PeerAdvertisement.maxURLCandidates).enumerated() {
            txt["u\(index)"] = url.absoluteString
        }
        for (index, chunk) in systemChunks(systems).enumerated() {
            txt[index == 0 ? "sys" : "sys\(index)"] = chunk
        }
        if let catalogueVersion {
            txt["cv"] = String(catalogueVersion.prefix(8))
        }
        return txt
    }

    /// Compact ids, sorted, comma-joined, split so no value passes
    /// `maxSystemsBytes`. `["*"]` when unspecified.
    static func systemChunks(_ systems: Set<SystemIdentifier>?) -> [String] {
        guard let systems else { return ["*"] }
        // An empty value says "nothing shared", not "unspecified".
        guard !systems.isEmpty else { return [""] }
        var chunks: [String] = []
        var current = ""
        for name in systems.subtracting([.Unknown]).map(SystemMap.compact).sorted() {
            let candidate = current.isEmpty ? name : current + "," + name
            if candidate.utf8.count > maxSystemsBytes, !current.isEmpty {
                chunks.append(current)
                current = name
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
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
    private let pvLibrary: PVLibraryDialectServer
    private let sharing = SharingFlag()

    private var listeners: [ServedDialect: LibraryHTTPListener] = [:]
    private var advertisers: [ServedDialect: BonjourAdvertiser] = [:]
    /// The `sys` set each live advert carries, so an unchanged one isn't republished.
    private var advertisedSystems: [ServedDialect: Set<SystemIdentifier>] = [:]

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
        pvLibrary = PVLibraryDialectServer(
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
        advertisedSystems.removeAll()
        await iFly.revokeAll()
        await iCube.revokeAll()
        await pvLibrary.revokeAll()
    }

    /// Re-reads the shared library and publishes or withdraws each dialect's
    /// advert, with its `sys` list. Call after an import, a deletion or a
    /// sharing-settings change.
    public func refreshAdvertisements() async {
        guard sharing.value else { return }
        let shared = Set(await library.sharedGames().map(\.system))
        for dialect in ServedDialect.allCases {
            let systems = shared.intersection(dialect.systems)
            let wanted = dialect.alwaysPublished || !systems.isEmpty
            if wanted, advertisers[dialect] != nil, advertisedSystems[dialect] == systems { continue }
            if let advertiser = advertisers.removeValue(forKey: dialect) {
                await advertiser.withdraw()
                advertisedSystems[dialect] = nil
            }
            guard wanted, let port = listeners[dialect]?.port else { continue }
            // iCube and iFly list this name under Nearby Devices.
            let advertiser = BonjourAdvertiser(type: dialect.serviceType, name: "Provenance on \(device.name)", port: port)
            await advertiser.publish(txt: LibraryAdvertTXT.record(
                peerId: identity.id, urls: LANFilter.baseURLs(port: port), systems: systems
            ))
            advertisers[dialect] = advertiser
            advertisedSystems[dialect] = systems
        }
    }

    /// Forgets one peer's tokens (removed from Trusted Devices).
    public func revoke(peerId: String) async {
        await iFly.revoke(peerId: peerId)
        await iCube.revoke(peerId: peerId)
        await pvLibrary.revoke(peerId: peerId)
    }

    private func handler(for dialect: ServedDialect) -> ServerRequestHandler {
        switch dialect {
        case .iFly:
            let server = iFly
            return { await server.handle($0) }
        case .iCube:
            let server = iCube
            return { await server.handle($0) }
        case .pvLibrary:
            let server = pvLibrary
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

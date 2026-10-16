//
//  PeerAdvertisement.swift
//  PVLibrarySharing
//
//  The library-relevant part of a continuity Bonjour TXT record.
//

import Foundation
import PVSystems

/// What a peer's TXT record says, decoded the way both apps'
/// `ContinuityTXTRecord.decode` do (iFly ContinuityKit and iCube PVContinuity
/// share the codec family).
///
/// | Key       | Meaning                                                          |
/// |-----------|------------------------------------------------------------------|
/// | `v`       | Payload version (required, integer)                              |
/// | `sid`     | Session id (required). A fresh UUID per advert, so never an id   |
/// | `lib`     | `"1"` when the device shares its library                         |
/// | `pid`     | Stable peer id (the pairing identity's id)                       |
/// | `u0..u3`  | Base URLs, tried in order; decoding stops at the first gap       |
/// | `tok`     | Handoff token; absent on library adverts, never used here        |
/// | `dt`      | Device type code (iCube); optional                               |
///
/// Game keys (`name`, `plat`, `gid`, `md5`, …) ride only on handoff adverts
/// and are out of scope here.
///
/// v1.1 adds, all optional and ignored by older peers (spec §3.2): `app`
/// (provenance/ifly/icube/ecs), `lx` (library-extension level), `sys`,
/// `sys1`, `sys2`… (compact system ids with a shareable item, ≤240 bytes per
/// key; `*` = unspecified) and `cv` (catalogue-version prefix).
public struct PeerAdvertisement: Sendable, Equatable {
    public static let maxURLCandidates = 4

    public var payloadVersion: Int
    public var sessionId: String
    public var sharesLibrary: Bool
    public var peerId: String?
    public var urlCandidates: [URL]
    public var deviceType: String?
    /// v1.1 `app`, e.g. "provenance".
    public var appName: String?
    /// v1.1 `lx`; nil for a legacy-only advert.
    public var extensionLevel: Int?
    /// v1.1 `sys*`; nil when absent or `*` (unspecified).
    public var systems: Set<SystemIdentifier>?
    /// v1.1 `cv`.
    public var catalogueVersion: String?

    public init(
        payloadVersion: Int,
        sessionId: String,
        sharesLibrary: Bool,
        peerId: String?,
        urlCandidates: [URL],
        deviceType: String? = nil,
        appName: String? = nil,
        extensionLevel: Int? = nil,
        systems: Set<SystemIdentifier>? = nil,
        catalogueVersion: String? = nil
    ) {
        self.payloadVersion = payloadVersion
        self.sessionId = sessionId
        self.sharesLibrary = sharesLibrary
        self.peerId = peerId
        self.urlCandidates = urlCandidates
        self.deviceType = deviceType
        self.appName = appName
        self.extensionLevel = extensionLevel
        self.systems = systems
        self.catalogueVersion = catalogueVersion
    }

    /// nil when `v` or `sid` is missing or `v` isn't an integer, as in both apps.
    public init?(txt: [String: String]) {
        guard let rawVersion = txt["v"], let version = Int(rawVersion), let sessionId = txt["sid"] else {
            return nil
        }
        var urls: [URL] = []
        for index in 0..<Self.maxURLCandidates {
            guard let raw = txt["u\(index)"], let url = URL(string: raw) else { break }
            urls.append(url)
        }
        self.init(
            payloadVersion: version,
            sessionId: sessionId,
            sharesLibrary: txt["lib"] == "1",
            peerId: txt["pid"],
            urlCandidates: urls,
            deviceType: txt["dt"],
            appName: txt["app"],
            extensionLevel: txt["lx"].flatMap(Int.init),
            systems: Self.decodeSystems(txt),
            catalogueVersion: txt["cv"]
        )
    }

    /// Joins `sys`, `sys1`, `sys2`… (stopping at the first gap). Unknown ids
    /// are dropped; nil when no key is present or the value is `*`.
    static func decodeSystems(_ txt: [String: String]) -> Set<SystemIdentifier>? {
        var parts: [String] = []
        if let first = txt["sys"] { parts.append(first) } else { return nil }
        var index = 1
        while let next = txt["sys\(index)"] {
            parts.append(next)
            index += 1
        }
        let values = parts.joined(separator: ",").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if values.contains("*") { return nil }
        return Set(values.compactMap { SystemMap.systemIdentifier(compact: $0) })
    }

    /// Whether this peer may have something for `playable`: true when it
    /// doesn't say (legacy, or `sys=*`).
    public func mayServe(_ playable: Set<SystemIdentifier>) -> Bool {
        guard let systems else { return true }
        return !systems.isDisjoint(with: playable)
    }
}

/// A library found on the LAN.
public struct DiscoveredPeer: Sendable, Equatable, Identifiable {
    public var app: PeerApp
    /// The Bonjour instance name, e.g. "iFly Joe's iPad".
    public var serviceName: String
    public var advertisement: PeerAdvertisement

    /// Stable across re-adverts: `(app, pid)`. `sid` changes every advert and
    /// iCube swaps it when a handoff starts, so it can't be the id.
    public var id: String { "\(app.rawValue):\(advertisement.peerId ?? serviceName)" }

    public var baseURLs: [URL] { advertisement.urlCandidates }

    public init(app: PeerApp, serviceName: String, advertisement: PeerAdvertisement) {
        self.app = app
        self.serviceName = serviceName
        self.advertisement = advertisement
    }

    /// Maps one browse result. Returns nil for adverts that aren't a shared
    /// library (`lib` missing), have no URL to call, or don't decode.
    /// A pure function so it can be tested without `NWBrowser`.
    public static func make(serviceType: String, serviceName: String, txt: [String: String]) -> DiscoveredPeer? {
        guard let app = PeerApp(serviceType: serviceType),
              let advertisement = PeerAdvertisement(txt: txt),
              advertisement.sharesLibrary,
              !advertisement.urlCandidates.isEmpty else {
            return nil
        }
        return DiscoveredPeer(app: app, serviceName: serviceName, advertisement: advertisement)
    }

    /// One entry per device and app, sorted by app then name. A device that
    /// advertises several types with the same `pid` and `app` (Provenance
    /// publishes `_pvlibrary._tcp` beside the legacy types, all `app=provenance`)
    /// is listed once, preferring `_pvlibrary._tcp`, which serves every system
    /// it shares.
    public static func deduplicated(_ peers: [DiscoveredPeer]) -> [DiscoveredPeer] {
        var byDevice: [String: DiscoveredPeer] = [:]
        var order: [String] = []
        for peer in peers {
            // Keyed by app too: with a team-shared identity (spec open question 5)
            // iFly and iCube on one device share a pid but are different libraries.
            let appKey = peer.advertisement.appName?.lowercased() ?? peer.app.rawValue
            let device = peer.advertisement.peerId.map { "\(appKey):\($0)" } ?? peer.id
            if let existing = byDevice[device] {
                if existing.app != .pvLibrary && peer.app == .pvLibrary { byDevice[device] = peer }
            } else {
                byDevice[device] = peer
                order.append(device)
            }
        }
        return order.compactMap { byDevice[$0] }
            .sorted { lhs, rhs in
                if lhs.app != rhs.app { return lhs.app.rawValue < rhs.app.rawValue }
                return lhs.serviceName.localizedCaseInsensitiveCompare(rhs.serviceName) == .orderedSame
                    ? lhs.id < rhs.id
                    : lhs.serviceName.localizedCaseInsensitiveCompare(rhs.serviceName) == .orderedAscending
            }
    }

    /// True for this Provenance's own adverts (`app=provenance` and our `pid`).
    public func isOwnAdvert(peerId: String?) -> Bool {
        guard let peerId else { return false }
        return advertisement.peerId == peerId && advertisement.appName?.lowercased() == "provenance"
    }

    /// Whether Nearby Libraries lists this peer on a device whose own peer id
    /// is `ownPeerId` and that plays `playable`: never this device's own
    /// advert (Share This Library is on), only an app that serves a system
    /// this device plays, and not a peer whose v1.1 `sys` says it has none.
    public func isVisible(ownPeerId: String?, playable: Set<SystemIdentifier>) -> Bool {
        !isOwnAdvert(peerId: ownPeerId)
            && !SystemMap.systems(servedBy: app).isDisjoint(with: playable)
            && advertisement.mayServe(playable)
    }

    /// The app behind the advert, from v1.1 `app` when present.
    public var appDisplayName: String {
        switch advertisement.appName?.lowercased() {
        case "ifly": return "iFly"
        case "icube": return "iCube"
        case "provenance": return "Provenance"
        case "ecs": return "Content Server"
        default: return app.displayName
        }
    }
}

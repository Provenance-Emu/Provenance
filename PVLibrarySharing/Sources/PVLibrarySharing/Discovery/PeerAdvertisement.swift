//
//  PeerAdvertisement.swift
//  PVLibrarySharing
//
//  The library-relevant part of a continuity Bonjour TXT record.
//

import Foundation

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
public struct PeerAdvertisement: Sendable, Equatable {
    public static let maxURLCandidates = 4

    public var payloadVersion: Int
    public var sessionId: String
    public var sharesLibrary: Bool
    public var peerId: String?
    public var urlCandidates: [URL]
    public var deviceType: String?

    public init(
        payloadVersion: Int,
        sessionId: String,
        sharesLibrary: Bool,
        peerId: String?,
        urlCandidates: [URL],
        deviceType: String? = nil
    ) {
        self.payloadVersion = payloadVersion
        self.sessionId = sessionId
        self.sharesLibrary = sharesLibrary
        self.peerId = peerId
        self.urlCandidates = urlCandidates
        self.deviceType = deviceType
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
            deviceType: txt["dt"]
        )
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

    /// One entry per `id`, keeping the first seen; sorted by app then name.
    public static func deduplicated(_ peers: [DiscoveredPeer]) -> [DiscoveredPeer] {
        var seen = Set<String>()
        return peers
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.app != rhs.app { return lhs.app.rawValue < rhs.app.rawValue }
                return lhs.serviceName.localizedCaseInsensitiveCompare(rhs.serviceName) == .orderedAscending
            }
    }
}

//
//  PeerApp.swift
//  PVLibrarySharing
//
//  The sibling apps whose library contract Provenance speaks.
//

import Foundation

/// An app that shares its library on the LAN with the continuity contract.
///
/// Each app speaks its own dialect of that contract: the same route paths mean
/// different things, and the auth signatures use a per-app domain prefix, so a
/// signature made for one app never verifies on the other (spec §1.3).
public enum PeerApp: String, CaseIterable, Sendable, Codable, Hashable {
    /// iFly (Dreamcast / NAOMI / Atomiswave). `iFly/Externals/ContinuityKit`.
    case iFly = "ifly"
    /// iCube (GameCube / Wii). `dolphin-ios/Source/iOS/PVContinuity`.
    case iCube = "icube"
    /// The shared v1.1 type `_pvlibrary._tcp` (spec §3.2): iCube's route shape,
    /// iFly's consent auth, neutral `pvlibrary-*` prefixes, dotted system ids.
    /// Provenance speaks it today; the advert's `app` key says which app.
    case pvLibrary = "pvlibrary"
    /// Provenance-Emu/emulator-content-server (`/api/v1`, spec §1.4, §3.7).
    /// Added by URL in Settings; `_pvcontent._tcp` adverts aren't browsed yet.
    case contentServer = "ecs"

    /// The Bonjour service type each app advertises its library under.
    ///
    /// `_icube-continuity._tcp` is 16 characters, one over the RFC 6335 limit
    /// of 15. iCube browses it successfully between its own devices, but a
    /// browse failure for this type must be surfaced, never swallowed
    /// (`PeerBrowser.State`).
    public var serviceType: String {
        switch self {
        case .iFly: return "_ifly-continuity._tcp"
        case .iCube: return "_icube-continuity._tcp"
        case .pvLibrary: return "_pvlibrary._tcp"
        case .contentServer: return "_pvcontent._tcp"
        }
    }

    /// User-facing app name.
    public var displayName: String {
        switch self {
        case .iFly: return "iFly"
        case .iCube: return "iCube"
        case .pvLibrary: return "Provenance"
        case .contentServer: return "Content Server"
        }
    }

    /// The domain prefix the app's library-auth signature is bound to.
    public var authDomain: ContinuityAuthDomain {
        switch self {
        case .iFly: return .iFly
        case .iCube: return .iCube
        case .pvLibrary, .contentServer: return .pvLibrary
        }
    }

    /// The app whose advertisements use `serviceType`, or nil.
    public init?(serviceType: String) {
        let normalized = serviceType.hasSuffix(".") ? String(serviceType.dropLast()) : serviceType
        guard let app = PeerApp.allCases.first(where: { $0.serviceType == normalized }) else { return nil }
        self = app
    }
}

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
        }
    }

    /// User-facing app name.
    public var displayName: String {
        switch self {
        case .iFly: return "iFly"
        case .iCube: return "iCube"
        }
    }

    /// The domain prefix the app's library-auth signature is bound to.
    public var authDomain: ContinuityAuthDomain {
        switch self {
        case .iFly: return .iFly
        case .iCube: return .iCube
        }
    }

    /// The app whose advertisements use `serviceType`, or nil.
    public init?(serviceType: String) {
        let normalized = serviceType.hasSuffix(".") ? String(serviceType.dropLast()) : serviceType
        guard let app = PeerApp.allCases.first(where: { $0.serviceType == normalized }) else { return nil }
        self = app
    }
}

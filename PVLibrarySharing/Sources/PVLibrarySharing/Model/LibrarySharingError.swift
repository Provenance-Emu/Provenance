//
//  LibrarySharingError.swift
//  PVLibrarySharing
//

import Foundation

/// Why browsing a peer failed, in terms the UI can explain.
public enum LibrarySharingError: Error, Equatable, Sendable {
    /// The peer isn't sharing (iFly 401/404 on auth or manifest).
    case sharingUnavailable
    /// iCube: `library/auth/start` answered 403. Either this device isn't
    /// paired or the host isn't sharing with it; iCube does not tell the two
    /// apart on purpose. Offer pairing.
    case notPaired
    /// The host owner declined (iFly "Don't share", iCube pairing declined).
    case declined
    /// The host owner didn't answer the consent or pairing prompt in time.
    case approvalTimedOut
    /// iCube pairing: the code was wrong; the host allows a few more tries.
    case wrongCode
    /// The auth challenge or pairing expired (410), or ran out of code tries.
    case expired
    /// iCube: too many devices browsing at once (429).
    case tooManyPeers
    /// The catalogue's `version` is one this client doesn't understand.
    case unsupportedCatalogueVersion(Int)
    /// The peer advertised no usable base URL, or none answered.
    case unreachable
    /// Any other HTTP status.
    case invalidResponse(status: Int)
}

extension LibrarySharingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sharingUnavailable:
            return "This device isn't sharing its library right now."
        case .notPaired:
            return "Pair with this device to browse its library."
        case .declined:
            return "The other device declined."
        case .approvalTimedOut:
            return "Nobody answered on the other device. Try again."
        case .wrongCode:
            return "That code didn't match. Check the code on the other device."
        case .expired:
            return "The request expired. Try again."
        case .tooManyPeers:
            return "Too many devices are browsing that library. Try again later."
        case .unsupportedCatalogueVersion(let version):
            return "That library uses a newer format (version \(version)). Update Provenance."
        case .unreachable:
            return "Couldn't reach the other device. Check that both are on the same Wi-Fi."
        case .invalidResponse(let status):
            return "The other device answered with an unexpected error (HTTP \(status))."
        }
    }
}

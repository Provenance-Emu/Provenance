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

    // MARK: Copying (phase 2)

    /// The host owner declined this one copy (iFly "Ask per game"). Browsing
    /// still works.
    case pullDeclined
    /// iFly 429: the host's free copies for today are used up.
    case hostLimitReached
    /// The game is gone from the host, or the owner excluded it (404 on the
    /// pull or manifest route; iCube doesn't tell the two apart).
    case itemUnavailable
    /// The host no longer serves a file of a granted manifest (404 on the
    /// file route).
    case fileUnavailable(String)
    /// A downloaded file's SHA-256 didn't match the manifest. The partial file
    /// was deleted.
    case checksumMismatch(String)
    /// A manifest path that would land outside the staging folder.
    case unsafePath(String)
    /// The host offered no game file for the item.
    case nothingToCopy

    // MARK: Content servers (phase 5)

    /// The content server refused the username or password.
    case signInFailed
    /// The content server speaks a protocol major version this build doesn't.
    case unsupportedServer(String)
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
        case .pullDeclined:
            return "The other device declined this copy."
        case .hostLimitReached:
            return "That device has used up its free copies for today. iFly Pro on that device removes the limit."
        case .itemUnavailable:
            return "That game isn't shared anymore."
        case .fileUnavailable(let name):
            return "The other device stopped offering \(name). Try the copy again."
        case .checksumMismatch(let name):
            return "\(name) arrived damaged. Try the copy again."
        case .unsafePath(let path):
            return "The other device offered a file with an unsafe path (\(path))."
        case .nothingToCopy:
            return "The other device offered nothing to copy for this game."
        case .signInFailed:
            return "The content server didn't accept that username and password."
        case .unsupportedServer(let detail):
            return "That content server isn't compatible with this version of Provenance (\(detail))."
        }
    }
}

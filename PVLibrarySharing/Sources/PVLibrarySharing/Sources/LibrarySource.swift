//
//  LibrarySource.swift
//  PVLibrarySharing
//
//  One abstraction over every place a library can come from (spec §2).
//

import Foundation

/// What the UI reports while a browse is in progress.
public enum LibraryBrowseProgress: Sendable, Equatable {
    case connecting
    /// The host is showing a consent prompt (iFly) and the client is polling.
    case waitingForApproval
    case loadingCatalogue
}

/// A peer library: iFly, iCube, and later another Provenance or an
/// emulator-content-server.
///
/// Phase 1 browses only. Phase 2 adds `manifest(for:)` and a resumable
/// `download(_:to:resumeFrom:)` here, so every source shares one pull path.
public protocol LibrarySource: Actor {
    var app: PeerApp { get }

    /// The whole shared catalogue, authenticating first when needed.
    func catalogue(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue

    /// Cover art bytes for `item`, or nil when the host has none.
    func artwork(for item: RemoteLibraryItem) async throws -> Data?
}

/// Tries a peer's advertised base URLs (`u0..u3`) in order.
///
/// Sends `build(base)` to `preferred` when set, otherwise to each candidate
/// until one answers. Only transport failures move on to the next candidate;
/// any HTTP status counts as an answer. Returns the base that answered so the
/// caller can stick with it.
func sendToFirstReachable(
    candidates: [URL],
    preferred: URL?,
    transport: any LibraryHTTPTransport,
    _ build: @Sendable (URL) throws -> LibraryHTTPRequest
) async throws -> (LibraryHTTPResponse, URL) {
    if let preferred {
        return (try await transport.send(build(preferred)), preferred)
    }
    for candidate in candidates {
        try Task.checkCancellation()
        do {
            return (try await transport.send(build(candidate)), candidate)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            continue
        }
    }
    throw LibrarySharingError.unreachable
}

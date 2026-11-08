//
//  LibraryAdvertSync.swift
//  PVLibrarySharing
//
//  What to do with a library advert when its listener changes.
//

/// Decides what happens to one dialect's Bonjour advert when its listener changes.
///
/// An advert must never name a port this app doesn't hold. iFly and iCube run
/// their own servers on the same device, and iOS defuncts a suspended app's
/// sockets, so after a resume our old port can belong to someone else. A peer
/// following a stale advert would land on the other app. Same rule as iFly's
/// `ContinuitySessionAdvertSync`.
public enum LibraryAdvertSync {
    public enum Action: Equatable, Sendable {
        /// The advert already matches the live listener.
        case keep
        /// No listener, or the dialect has nothing to share: take the advert down.
        case withdraw
        /// Rebuild the advert from the live listener and publish it.
        case republish
    }

    /// - Parameters:
    ///   - wanted: The dialect should be advertised (it shares something, or always does).
    ///   - listenerPort: The port the dialect's listener holds now, `nil` while it is down.
    ///   - advertisedPort: The port the live advert names, `nil` when nothing is published.
    ///   - contentChanged: The TXT record would differ (systems, URLs).
    public static func action(
        wanted: Bool,
        listenerPort: UInt16?,
        advertisedPort: UInt16?,
        contentChanged: Bool
    ) -> Action {
        guard wanted, let listenerPort, listenerPort > 0 else {
            return advertisedPort == nil ? .keep : .withdraw
        }
        if advertisedPort != listenerPort || contentChanged {
            return .republish
        }
        return .keep
    }
}

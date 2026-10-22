import Foundation

/// Optional read-only identity capability. Implementations must not start emulation.
@objc public protocol PVLibraryDiscIdentityReading {
    /// Returns observed gameID, discNumber and revision, or nil when unresolved.
    /// Consumers must validate/copy the result before crossing an actor boundary.
    @objc(libraryIdentityAtPath:)
    static func libraryIdentity(atPath path: String) -> [String: Any]?
}

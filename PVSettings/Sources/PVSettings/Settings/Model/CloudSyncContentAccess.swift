import Foundation

/// Runtime admission scope; never rewrites the user's saved sync configuration.
public enum CloudSyncContentAccess {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        #if os(tvOS)
        var restrictROMAutomation = false
        #else
        // Cold/background launches admit metadata until distribution/ownership is published.
        var restrictROMAutomation = true
        #endif
    }
    private static let state = State()

    /// The app publishes pending/unpaid App Store ownership; other distributions retain their baseline.
    public static func updateOwnership(isTV: Bool, isAppStore: Bool, isSettled: Bool, hasPlus: Bool) {
        state.lock.lock()
        defer { state.lock.unlock() }
        state.restrictROMAutomation = !isTV && isAppStore && (!isSettled || !hasPlus)
    }

    /// Free save, progress and metadata sync continues while automatic ROM payloads are restricted.
    public static func effectiveScope(for requested: CloudKitSyncContentType) -> CloudKitSyncContentType {
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.restrictROMAutomation ? .metadataOnly : requested
    }
}

//
//  CloudSyncSafetyNet.swift
//  PVLibrary
//
//  Step 1 of docs/superpowers/specs/2026-11-25-cloud-sync-shared-packages-design.md.
//

import Foundation
import CloudKit
import Defaults
import PVCloudSync
import PVLogging
import PVSupport

public extension Defaults.Keys {
    /// Keeps the local copy of a file that a cloud download is about to replace, and uses the
    /// shared retry policy. Off by default until it has run against real libraries.
    static let cloudSyncSafetyNet = Key<Bool>("cloudSyncSafetyNet", default: false)
}

/// The only file in PVLibrary that imports PVCloudSync. That module's `SyncProvider` and
/// `SyncStatus` share names with PVLibrary's own types, so nothing else may import it.
///
/// It changes no CloudKit record. It decides two things locally: where a file goes before a
/// download replaces it, and how long to wait before a failed CloudKit call is tried again.
public enum CloudSyncSafetyNet {

    /// How long a replaced file is kept.
    public static let trashRetention: TimeInterval = CloudSyncConstants.trashRetention

    public static var isEnabled: Bool { Defaults[.cloudSyncSafetyNet] }

    // MARK: - Replaced files

    /// Outside the library folders, so no syncer scans it and Files never shows it. Apple TV can
    /// write only to Caches, where the system may purge it.
    static var trashRootURL: URL {
        #if os(tvOS)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        #endif
        return (base ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("CloudSyncReplacedFiles", isDirectory: true)
    }

    private static let sharedTrash = SyncTrash(rootURL: trashRootURL)

    /// Call before a downloaded file replaces `localURL`. When the safety net is on and the two
    /// files differ, the local one is moved into the trash; the caller's own "remove if it
    /// exists" then finds nothing. A failure is logged and the download goes ahead as before.
    public static func preserveLocalFile(at localURL: URL, replacedBy incomingURL: URL) async {
        guard isEnabled else { return }
        await preserveLocalFile(
            at: localURL,
            replacedBy: incomingURL,
            libraryRoot: URL.documentsPath,
            trash: sharedTrash
        )
    }

    /// The rule itself, with its roots passed in so tests need no app container.
    /// - Returns: the trash entry, or nil when nothing had to be kept.
    @discardableResult
    static func preserveLocalFile(
        at localURL: URL,
        replacedBy incomingURL: URL,
        libraryRoot: URL,
        trash: SyncTrash,
        now: Date = Date()
    ) async -> SyncTrashEntry? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: localURL.path) else { return nil }
        // The same bytes coming back is the usual case and nothing is lost by it.
        if fileManager.contentsEqual(atPath: localURL.path, andPath: incomingURL.path) { return nil }

        let relativePath = CanonicalRelativePath.relativePath(of: localURL, under: libraryRoot)
            ?? localURL.lastPathComponent
        do {
            let entry = try await trash.move(fileAt: localURL, relativePath: relativePath, now: now)
            ILOG("Cloud sync kept the replaced copy of \(relativePath)")
            _ = await trash.purge(olderThan: now.addingTimeInterval(-trashRetention))
            return entry
        } catch {
            ELOG("Cloud sync could not keep the replaced copy of \(relativePath): \(error.localizedDescription)")
            return nil
        }
    }

    /// Replaced files still held, newest first.
    public static func replacedFiles() async -> [ReplacedFile] {
        await sharedTrash.entries().map(ReplacedFile.init)
    }

    /// Puts a replaced file back where it was, replacing what is there now.
    public static func restore(_ file: ReplacedFile) async throws {
        try await sharedTrash.restore(file.entry, into: URL.documentsPath)
    }

    /// A file the safety net kept. Wraps the package's type so callers need not import it.
    public struct ReplacedFile: Identifiable, Sendable {
        let entry: SyncTrashEntry

        public var id: String { entry.id }
        /// Path under the library's documents root.
        public var relativePath: String { entry.relativePath }
        public var replacedAt: Date { entry.deletedAt }
        public var fileSize: Int64 { entry.fileSize }
    }

    // MARK: - Retry

    /// Seconds to wait before trying a failed CloudKit call again, or nil to stop.
    /// - Parameters:
    ///   - attempt: 1 for the first failure.
    ///   - maximumAttempts: the caller's own limit on tries.
    public static func retryDelay(after error: CKError, attempt: Int, maximumAttempts: Int) -> TimeInterval? {
        let policy = SyncRetryPolicy(maximumAttempts: maximumAttempts)
        switch policy.decide(facts: SyncRetryFacts(ckError: error), attempt: attempt) {
        case .retry(let afterSeconds): return afterSeconds
        case .giveUp: return nil
        }
    }
}

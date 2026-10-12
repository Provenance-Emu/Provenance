//
//  LibraryMoveCoordinator.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The app-facing side of the move engine: knows the real roots, resumes a journaled move at
//  launch (`PVGameLibrary.init` calls `resumeIfNeeded()`), and starts the one move phase 2
//  supports, App Group → App storage. tvOS: no-op.
//

import Foundation
import PVHashing
import PVLogging

public final class LibraryMoveCoordinator: @unchecked Sendable {
    public static let shared = LibraryMoveCoordinator()

    private let journalStore: LibraryMoveJournalStore?
    private let rootProvider: @Sendable (LibraryLocation) -> URL?
    /// The location this process launched on (`LibraryLocation.current`); decides whether cleanup may run.
    private let launchedLocation: @Sendable () -> LibraryLocation
    private let planner: LibraryMovePlanner
    private let engine: LibraryMoveEngine?

    public init(journalStore: LibraryMoveJournalStore? = try? LibraryMoveJournalStore(url: LibraryMoveJournalStore.defaultURL()),
                rootProvider: @escaping @Sendable (LibraryLocation) -> URL? = LibraryMoveCoordinator.defaultRoot(for:),
                launchedLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.current },
                switchLocation: @escaping @Sendable (LibraryLocation) throws -> Void = LibraryLocation.switchStored(to:),
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                md5Provider: any MD5Provider = FileManager.default) {
        self.journalStore = journalStore
        self.rootProvider = rootProvider
        self.launchedLocation = launchedLocation
        self.planner = planner
        self.engine = journalStore.map {
            LibraryMoveEngine(journalStore: $0, md5Provider: md5Provider, planner: planner, switchLocation: switchLocation)
        }
    }

    /// The `Documents/` folder of each location. iCloud Drive is phase 5. Always `nil` on tvOS.
    public static func defaultRoot(for location: LibraryLocation) -> URL? {
        #if os(tvOS)
        return nil
        #else
        switch location {
        case .appStorage: return URL.documentsPathLocal
        case .appGroup: return URL.documentsPathAppGroup
        case .iCloudDrive: return nil
        }
        #endif
    }

    /// A journal exists: either a copy to finish or a cleanup owed on the next launch.
    public var hasPendingMove: Bool {
        journalStore?.load() != nil
    }

    /// Call once per launch, off the main thread. Finishes an interrupted copy (then switches), or runs
    /// the cleanup owed after a switch once this process has launched on the destination.
    /// - Returns: the outcome, or `nil` when there was nothing to do or it could not safely run.
    @discardableResult
    public func resumeIfNeeded(progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async -> LibraryMoveOutcome? {
        #if os(tvOS)
        return nil
        #else
        guard let engine, let journal = journalStore?.load() else { return nil }
        guard let sourceRoot = rootProvider(journal.source), let destinationRoot = rootProvider(journal.destination) else {
            ELOG("LibraryMove: a root for \(journal.source.rawValue) → \(journal.destination.rawValue) is unavailable; keeping the journal")
            return nil
        }
        let launched = launchedLocation()
        switch journal.phase {
        case .copying:
            guard launched == journal.source else {
                ELOG("LibraryMove: journal is mid-copy but this launch is on \(launched.rawValue); keeping the journal")
                return nil
            }
        case .switched, .cleaning:
            guard launched == journal.destination else {
                ILOG("LibraryMove: switch recorded but this launch is still on \(launched.rawValue); cleanup waits for a relaunch")
                return nil
            }
        }
        do {
            return try await engine.resume(journal, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        } catch {
            ELOG("LibraryMove: resume failed: \(error.localizedDescription)")
            return nil
        }
        #endif
    }

    /// Phase 2's one supported move. Moves every top-level entry of the App Group's Documents (except hidden
    /// entries and the Realm files), verifies, writes the setting and returns `.switched`; the caller tells the
    /// user to quit and reopen. Cleanup happens on that next launch.
    public func moveToAppStorage(keepCopy: Bool = false,
                                 progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        let source = launchedLocation()
        guard source == .appGroup else { throw LibraryMoveError.unsupportedMove(from: source, to: .appStorage) }
        guard let engine else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        guard let sourceRoot = rootProvider(.appGroup) else { throw LibraryMoveError.rootUnavailable(.appGroup) }
        guard let destinationRoot = rootProvider(.appStorage) else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        let request = LibraryMoveRequest(source: .appGroup, destination: .appStorage, sourceRoot: sourceRoot, destinationRoot: destinationRoot,
                                         folders: try planner.topLevelEntries(at: sourceRoot), keepCopy: keepCopy)
        return try await engine.start(request, progress: progress)
    }

    /// Stops a running copy at the next file and rolls it back. Ignored once the setting has been switched.
    public func cancel() {
        engine?.cancel()
    }
}

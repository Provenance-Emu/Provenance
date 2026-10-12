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
//  Leaving the App Group: Lite and the full app share one group container, so each app records where it
//  launched in the group's shared defaults, and a move forces "keep a copy" while another app still uses the group.
//

import Foundation
import PVHashing
import PVLogging

public final class LibraryMoveCoordinator: @unchecked Sendable {
    public static let shared = LibraryMoveCoordinator()

    private let journalStore: LibraryMoveJournalStore?
    private let rootProvider: @Sendable (LibraryLocation) -> URL?
    /// The location the library resolves to (`LibraryLocation.current`); gates starting a move.
    private let launchedLocation: @Sendable () -> LibraryLocation
    /// The appGroup/appStorage axis this process launched on. Unlike `launchedLocation` it ignores the live iCloud Drive
    /// setting, so a resume is not refused just because iCloud Drive mode is on.
    private let resumeLocation: @Sendable () -> LibraryLocation
    private let switchLocation: @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void
    private let planner: LibraryMovePlanner
    private let engine: LibraryMoveEngine?
    /// Defaults shared by every app of the App Group; each app records its location here (see `anotherVariantUsesAppGroup`).
    private let sharedDefaults: UserDefaults?
    /// This app's key suffix in `sharedDefaults`.
    private let variantID: String

    public init(journalStore: LibraryMoveJournalStore? = LibraryMoveCoordinator.defaultJournalStore(),
                rootProvider: @escaping @Sendable (LibraryLocation) -> URL? = { LibraryMoveCoordinator.defaultRoot(for: $0) },
                launchedLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.current },
                resumeLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.launchAxis },
                switchLocation: @escaping @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void = { try LibraryLocation.switchStored(to: $0, pickedFolder: $1) },
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                md5Provider: any MD5Provider = FileManager.default,
                sharedDefaults: UserDefaults? = UserDefaults(suiteName: PVAppGroupId),
                variantID: String = Bundle.main.bundleIdentifier ?? "") {
        self.journalStore = journalStore
        self.rootProvider = rootProvider
        self.launchedLocation = launchedLocation
        self.resumeLocation = resumeLocation
        self.switchLocation = switchLocation
        self.planner = planner
        self.sharedDefaults = sharedDefaults
        self.variantID = variantID
        self.engine = journalStore.map {
            LibraryMoveEngine(journalStore: $0, md5Provider: md5Provider, planner: planner, manifestAuthor: variantID, switchLocation: switchLocation)
        }
    }

    /// `<Application Support>/LibraryMove/move-journal.json`, or `nil` on tvOS, where the engine is a no-op and
    /// nothing should be created on disk.
    public static func defaultJournalStore() -> LibraryMoveJournalStore? {
        #if os(tvOS)
        return nil
        #else
        return (try? LibraryMoveJournalStore.defaultURL()).map { LibraryMoveJournalStore(url: $0) }
        #endif
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
        case .pickedFolder: return LibraryLocation.pickedFolderAtLaunch.url
        }
        #endif
    }

    /// A journal file exists: either a copy to finish or a cleanup owed on the next launch. A pure check.
    public var hasPendingMove: Bool {
        journalStore?.exists ?? false
    }

    /// Call once per launch, off the main thread. Finishes an interrupted copy (then switches), or runs
    /// the cleanup owed after a switch once this process has launched on the destination.
    /// - Returns: the outcome, or `nil` when there was nothing to do or it could not safely run.
    @discardableResult
    public func resumeIfNeeded(progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async -> LibraryMoveOutcome? {
        #if os(tvOS)
        return nil
        #else
        let launched = resumeLocation()
        recordLaunchLocation(launched)
        guard let engine, var journal = journalStore?.load() else { return nil }
        guard let sourceRoot = rootProvider(journal.source), let destinationRoot = rootProvider(journal.destination) else {
            ELOG("LibraryMove: a root for \(journal.source.rawValue) → \(journal.destination.rawValue) is unavailable; keeping the journal")
            return nil
        }
        switch journal.phase {
        case .copying:
            if launched == journal.destination, journal.inFlight.isEmpty {
                // `performSwitch` wrote the setting, then the process died before the journal said so (`inFlight` is
                // cleared only when the copy loop completes). Record the switch and clean up now: this launch is on the
                // destination, and the delta sweep copies anything the journal lacks before any source is deleted.
                journal.phase = .switched
                journal.updatedAt = Date()
                do {
                    try journalStore?.save(journal)
                } catch {
                    ELOG("LibraryMove: could not record the switch: \(error.localizedDescription)")
                    return nil
                }
            } else if launched != journal.source {
                ELOG("LibraryMove: journal is mid-copy but this launch is on \(launched.rawValue); keeping the journal")
                return nil
            }
        case .switched, .cleaning:
            guard launched == journal.destination else {
                if launched == journal.source {
                    // The switch is journaled but the setting didn't stick (UserDefaults not persisted before the process
                    // died). Re-assert it; cleanup runs on the next launch.
                    try? switchLocation(journal.destination, journal.destinationFolder)
                }
                ILOG("LibraryMove: switch recorded but this launch is still on \(launched.rawValue); cleanup waits for a relaunch")
                return nil
            }
        }
        if journal.phase != .copying {
            journal = carryNewTopLevelEntries(journal, sourceRoot: sourceRoot)
            journal = keepingCopyWhileAnotherVariantUsesTheGroup(journal)
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
                                         folders: try planner.topLevelEntries(at: sourceRoot), keepCopy: keepCopy || anotherVariantUsesAppGroup())
        return try await engine.start(request, progress: progress)
    }

    // MARK: - Shared App Group

    private var variantKey: String {
        LibraryMoveFolders.variantLocationKeyPrefix + variantID
    }

    /// Writes where this app launched into the group's shared defaults, so the group's other apps can see it.
    private func recordLaunchLocation(_ location: LibraryLocation) {
        sharedDefaults?.set(location.rawValue, forKey: variantKey)
    }

    /// `true` when another app of the App Group (Lite beside the full app) last launched on the App Group. Moving out
    /// would delete the library it is still reading, so a move keeps a copy while this is true. An app that has never
    /// recorded a location is invisible here, and a record outlives an uninstall; both err towards keeping the copy
    /// or, for a never-launched app, towards the legacy behaviour.
    private func anotherVariantUsesAppGroup() -> Bool {
        guard let sharedDefaults else { return false }
        let ours = variantKey
        return sharedDefaults.dictionaryRepresentation().contains { entry in
            entry.key.hasPrefix(LibraryMoveFolders.variantLocationKeyPrefix) && entry.key != ours
                && (entry.value as? String) == LibraryLocation.appGroup.rawValue
        }
    }

    /// Forces "keep a copy" (and journals it) while another app still uses the group.
    private func keepingCopyWhileAnotherVariantUsesTheGroup(_ journal: LibraryMoveJournal) -> LibraryMoveJournal {
        guard journal.source == .appGroup, !journal.keepCopy, anotherVariantUsesAppGroup() else { return journal }
        var updated = journal
        updated.keepCopy = true
        updated.updatedAt = Date()
        do {
            try journalStore?.save(updated)
        } catch {
            ELOG("LibraryMove: could not journal keep-a-copy: \(error.localizedDescription)")
        }
        ILOG("LibraryMove: another app still uses the App Group; the group's files stay")
        return updated
    }

    /// R5: an App Group exit carries every top-level entry, including ones created after the move started
    /// (a core's first folder, a loose file). Persisted before the sweep, so a crash mid-cleanup keeps them and
    /// `removeEmptyDirectories` covers them. Hidden, `.realm` and journal names stay excluded by `topLevelEntries`.
    private func carryNewTopLevelEntries(_ journal: LibraryMoveJournal, sourceRoot: URL) -> LibraryMoveJournal {
        guard journal.source == .appGroup, let journalStore,
              let fresh = try? planner.topLevelEntries(at: sourceRoot) else { return journal }
        let added = fresh.filter { !journal.folders.contains($0) }
        guard !added.isEmpty else { return journal }
        var updated = journal
        updated.folders = (journal.folders + added).sorted()
        updated.updatedAt = Date()
        do {
            try journalStore.save(updated)
        } catch {
            ELOG("LibraryMove: could not journal new top-level entries: \(error.localizedDescription)")
            return journal
        }
        ILOG("LibraryMove: cleanup also carries \(added.joined(separator: ", "))")
        return updated
    }
}

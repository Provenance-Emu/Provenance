//
//  LibraryMoveCoordinator.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The app-facing side of the move engine: knows the real roots, resumes a journaled move at
//  launch (`PVGameLibrary.init` calls `resumeIfNeeded()`), and starts the moves phases 2 and 3 support:
//  App Group → App storage, and App storage ⇄ a picked folder (and picked folder → picked folder). tvOS: no-op.
//
//  Leaving the App Group: Lite and the full app share one group container, so each app records where it
//  launched in the group's shared defaults, and a move forces "keep a copy" while another app still uses the group.
//

import Foundation
import PVHashing
import PVLogging

public final class LibraryMoveCoordinator: @unchecked Sendable {
    public static let shared = LibraryMoveCoordinator()

    public typealias RootProvider = @Sendable (LibraryLocation, PickedLibraryFolder?) -> URL?

    /// Rewrites the database so records named by a journal's `remaps` (source path → shared path) point at the shared copies.
    /// Returns the source paths (the keys) whose record now follows the shared copy; a key it leaves out is not safe to clean up.
    public typealias PathRemapApplier = @Sendable ([String: String]) async throws -> Set<String>

    private let journalStore: LibraryMoveJournalStore?
    private let rootProvider: RootProvider
    /// The location the library resolves to (`LibraryLocation.current`); gates starting a move.
    private let launchedLocation: @Sendable () -> LibraryLocation
    /// The axis this process launched on (`LibraryLocation.launchAxis`). Unlike `launchedLocation` it ignores the live
    /// iCloud Drive setting, so a resume is not refused just because iCloud Drive mode is on.
    private let resumeLocation: @Sendable () -> LibraryLocation
    /// The picked folder this process launched on; `nil` unless `resumeLocation()` is `.pickedFolder`.
    private let launchedFolder: @Sendable () -> PickedLibraryFolder?
    private let switchLocation: @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void
    private let folderStore: PickedLibraryFolderStore
    private let planner: LibraryMovePlanner
    private let engine: LibraryMoveEngine?
    private let remapLock = NSLock()
    private var remapApplier: PathRemapApplier?
    /// Defaults shared by every app of the App Group; each app records its location here (see `anotherVariantUsesAppGroup`).
    private let sharedDefaults: UserDefaults?
    /// This app's key suffix in `sharedDefaults`.
    private let variantID: String

    public init(journalStore: LibraryMoveJournalStore? = LibraryMoveCoordinator.defaultJournalStore(),
                rootProvider: @escaping RootProvider = { LibraryMoveCoordinator.defaultRoot(for: $0, folder: $1) },
                launchedLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.current },
                resumeLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.launchAxis },
                launchedFolder: @escaping @Sendable () -> PickedLibraryFolder? = { LibraryLocation.launchAxis == .pickedFolder ? PickedLibraryFolderStore.shared.load() : nil },
                switchLocation: @escaping @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void = { try LibraryLocation.switchStored(to: $0, pickedFolder: $1) },
                folderStore: PickedLibraryFolderStore = .shared,
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                md5Provider: any MD5Provider = FileManager.default,
                sharedDefaults: UserDefaults? = UserDefaults(suiteName: PVAppGroupId),
                variantID: String = Bundle.main.bundleIdentifier ?? "") {
        self.journalStore = journalStore
        self.rootProvider = rootProvider
        self.launchedLocation = launchedLocation
        self.resumeLocation = resumeLocation
        self.launchedFolder = launchedFolder
        self.switchLocation = switchLocation
        self.folderStore = folderStore
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

    /// The root of each location. A picked folder is resolved from `folder` (a journaled one) or, when `nil`, the
    /// one this process launched on. iCloud Drive is phase 5. Always `nil` on tvOS.
    public static func defaultRoot(for location: LibraryLocation, folder: PickedLibraryFolder?) -> URL? {
        #if os(tvOS)
        return nil
        #else
        switch location {
        case .appStorage: return URL.documentsPathLocal
        case .appGroup: return URL.documentsPathAppGroup
        case .iCloudDrive: return nil
        case .pickedFolder:
            if let folder {
                do {
                    return try LibraryFolderBookmark.resolve(folder.bookmark).url
                } catch {
                    ELOG("LibraryMove: the journaled folder \(folder.displayName) does not resolve: \(error.localizedDescription)")
                    return nil
                }
            }
            return LibraryLocation.pickedFolderAtLaunch.url
        }
        #endif
    }

    /// Registers what rewrites the database when a join de-duplicated files (`LibraryPathRemapper` in PVLibrary).
    /// `PVGameLibrary.init` calls this before `resumeIfNeeded()`.
    public func setPathRemapApplier(_ applier: @escaping PathRemapApplier) {
        remapLock.lock()
        remapApplier = applier
        remapLock.unlock()
    }

    private func currentRemapApplier() -> PathRemapApplier? {
        remapLock.lock()
        defer { remapLock.unlock() }
        return remapApplier
    }

    /// A journal file exists: either a copy to finish or a cleanup owed on the next launch. A pure check.
    public var hasPendingMove: Bool {
        journalStore?.exists ?? false
    }

    /// Stops the running copy (before the switch). A no-op otherwise.
    public func cancelRunningMove() {
        engine?.cancel()
    }

    /// The folders a picked-folder move carries (D10).
    public static func folders(includeSaves: Bool) -> [String] {
        LibraryMoveFolders.shared + (includeSaves ? LibraryMoveFolders.saves : [])
    }

    /// `launched` is `location`, and for a picked folder the same pick (two picks of one folder differ by `pickedAt`).
    private func launchedOn(_ location: LibraryLocation, _ folder: PickedLibraryFolder?, launched: LibraryLocation) -> Bool {
        guard launched == location else { return false }
        guard location == .pickedFolder else { return true }
        return folder?.pickedAt == launchedFolder()?.pickedAt
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
        guard let sourceRoot = rootProvider(journal.source, journal.sourceFolder),
              let destinationRoot = rootProvider(journal.destination, journal.destinationFolder) else {
            ELOG("LibraryMove: a root for \(journal.source.rawValue) → \(journal.destination.rawValue) is unavailable; keeping the journal")
            return nil
        }
        let onDestination = launchedOn(journal.destination, journal.destinationFolder, launched: launched)
        let onSource = launchedOn(journal.source, journal.sourceFolder, launched: launched)
        switch journal.phase {
        case .copying:
            if onDestination, journal.inFlight.isEmpty {
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
            } else if !onSource {
                ELOG("LibraryMove: journal is mid-copy but this launch is on \(launched.rawValue); keeping the journal")
                return nil
            }
        case .switched, .cleaning:
            guard onDestination else {
                if onSource {
                    // The switch is journaled but the setting didn't stick (UserDefaults not persisted before the process
                    // died). Re-assert it; cleanup runs on the next launch.
                    try? switchLocation(journal.destination, journal.destinationFolder)
                }
                ILOG("LibraryMove: switch recorded but this launch is still on \(launched.rawValue); cleanup waits for a relaunch")
                return nil
            }
        }
        if journal.phase != .copying {
            if let remaps = journal.remaps, !remaps.isEmpty {
                // D15: records must point at the shared copies before their sources are deleted.
                guard let applier = currentRemapApplier() else {
                    ELOG("LibraryMove: \(remaps.count) record remaps are pending but no applier is registered; cleanup waits")
                    return nil
                }
                guard let confirmed = await confirmedRemaps(for: journal, destinationRoot: destinationRoot, applier: applier) else { return nil }
                let unconfirmed = Set(remaps.keys).subtracting(confirmed)
                if !unconfirmed.isEmpty {
                    // No record follows the shared copy (it vanished, or nothing names this source), so deleting the source
                    // could lose the only file a record still resolves to. Drop the dedup: cleanup's sweep copies it under its own name.
                    WLOG("LibraryMove: \(unconfirmed.count) remaps could not be confirmed; those sources are copied under their own names")
                    for key in unconfirmed {
                        journal.entries.removeValue(forKey: key)
                        journal.remaps?.removeValue(forKey: key)
                    }
                    if journal.remaps?.isEmpty == true { journal.remaps = nil }
                    journal.updatedAt = Date()
                    do {
                        try journalStore?.save(journal)
                    } catch {
                        ELOG("LibraryMove: could not journal the unconfirmed remaps: \(error.localizedDescription); cleanup waits")
                        return nil
                    }
                }
            }
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

    /// The remap keys it is safe to clean up: the shared copy still verifies at the destination and the applier rewrote
    /// (or had already rewritten) the record. `nil` when the applier throws, so cleanup waits for a later launch.
    private func confirmedRemaps(for journal: LibraryMoveJournal, destinationRoot: URL, applier: PathRemapApplier) async -> Set<String>? {
        let copier = LibraryMoveFileCopier()
        let present = (journal.remaps ?? [:]).filter { key, sharedPath in
            guard let entry = journal.entries[key] else { return false }
            return copier.verify(destinationRoot.appendingPathComponent(sharedPath), expectedSize: entry.size, expectedMD5: nil)
        }
        guard !present.isEmpty else { return [] }
        do {
            return try await applier(present).intersection(present.keys)
        } catch {
            ELOG("LibraryMove: applying record remaps failed: \(error.localizedDescription); cleanup waits")
            return nil
        }
    }

    /// From the App Group (phase 2: every top-level entry of its Documents except hidden entries and the Realm files) or
    /// from a picked folder (phase 3: the shared folders and, when that folder holds them, the saves folders; always keep a
    /// copy so the shared folder is left untouched). Verifies, writes the setting and returns `.switched`; the caller tells
    /// the user to quit and reopen. Cleanup happens on that next launch.
    public func moveToAppStorage(keepCopy: Bool = false,
                                 progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        let source = launchedLocation()
        guard source == .appGroup || source == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: source, to: .appStorage) }
        guard let engine else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        let sourceFolder = source == .pickedFolder ? launchedFolder() : nil
        guard let sourceRoot = rootProvider(source, sourceFolder) else { throw LibraryMoveError.rootUnavailable(source) }
        guard let destinationRoot = rootProvider(.appStorage, nil) else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        let folders: [String]
        let keep: Bool
        if source == .appGroup {
            folders = try planner.topLevelEntries(at: sourceRoot)
            keep = keepCopy || anotherVariantUsesAppGroup()
        } else {
            folders = Self.folders(includeSaves: sourceFolder?.includesSaves ?? false)
            keep = true
        }
        let request = LibraryMoveRequest(source: source, destination: .appStorage, sourceRoot: sourceRoot, destinationRoot: destinationRoot,
                                         folders: folders, keepCopy: keep, sourceFolder: sourceFolder)
        return try await engine.start(request, progress: progress)
    }

    /// Moves the shared folders (and the saves folders when `includeSaves`) into `url`, a folder from the picker that
    /// `LibraryFolderInspector` accepted. From App storage, or from another picked folder (which then keeps a copy and
    /// whose `includesSaves` decides what moves). `deduplicate` is phase 4's join (D15).
    public func moveToPickedFolder(_ url: URL, displayName: String, includeSaves: Bool, deduplicate: Bool = false,
                                   progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        let source = launchedLocation()
        guard source == .appStorage || source == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: source, to: .pickedFolder) }
        guard let engine else { throw LibraryMoveError.rootUnavailable(.pickedFolder) }
        let sourceFolder = source == .pickedFolder ? launchedFolder() : nil
        guard let sourceRoot = rootProvider(source, sourceFolder) else { throw LibraryMoveError.rootUnavailable(source) }
        let saves = sourceFolder?.includesSaves ?? includeSaves
        let folder = PickedLibraryFolder(bookmark: try LibraryFolderBookmark.make(from: url), displayName: displayName, includesSaves: saves)
        let request = LibraryMoveRequest(source: source, destination: .pickedFolder, sourceRoot: sourceRoot, destinationRoot: url.standardizedFileURL,
                                         folders: Self.folders(includeSaves: saves), keepCopy: source == .pickedFolder,
                                         sourceFolder: sourceFolder, destinationFolder: folder, deduplicateByMD5: deduplicate)
        return try await engine.start(request, progress: progress)
    }

    /// What `moveToPickedFolder` would carry and whether `destinationRoot` has room.
    public func preview(destinationRoot: URL, includeSaves: Bool) throws -> LibraryMovePreview {
        let source = launchedLocation()
        let sourceFolder = source == .pickedFolder ? launchedFolder() : nil
        guard let sourceRoot = rootProvider(source, sourceFolder) else { throw LibraryMoveError.rootUnavailable(source) }
        let plan = try planner.plan(root: sourceRoot, folders: Self.folders(includeSaves: sourceFolder?.includesSaves ?? includeSaves))
        return LibraryMovePreview(fileCount: plan.items.count, totalBytes: plan.totalBytes,
                                  requiredBytes: LibraryMovePlanner.requiredBytes(for: plan.totalBytes),
                                  availableBytes: try planner.availableCapacity(destinationRoot))
    }

    /// The saved folder no longer resolves and the user pointed at where it is now. A fresh bookmark; no files move;
    /// applies at the next launch.
    public func rebindPickedFolder(to url: URL, displayName: String) throws {
        let launched = resumeLocation()
        guard launched == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: launched, to: .pickedFolder) }
        let previous = launchedFolder() ?? folderStore.load()
        let folder = PickedLibraryFolder(bookmark: try LibraryFolderBookmark.make(from: url), displayName: displayName,
                                         includesSaves: previous?.includesSaves ?? false)
        try switchLocation(.pickedFolder, folder)
    }

    /// The saved folder is gone for good: back to App storage without a move. Records stay and show as missing.
    public func abandonPickedFolder() throws {
        let launched = resumeLocation()
        guard launched == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: launched, to: .appStorage) }
        try switchLocation(.appStorage, nil)
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

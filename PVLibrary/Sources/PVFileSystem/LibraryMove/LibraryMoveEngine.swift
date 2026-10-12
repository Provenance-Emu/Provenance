//
//  LibraryMoveEngine.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Plan → copy+verify → switch, journaled so it resumes after a crash and cancellable (with
//  rollback) until the switch. Cleanup (delete sources) is `LibraryMoveEngine+Cleanup.swift`
//  and runs on the launch after the switch.
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md
//

import Foundation
import PVHashing
import PVLogging

public actor LibraryMoveEngine {
    /// The journal is written after this many files (and at every phase change).
    static let journalFlushInterval = 25

    /// Pairs the engine knows how to move. Phase 5 adds iCloud Drive both ways.
    static let supportedMoves: Set<[LibraryLocation]> = [[.appGroup, .appStorage]]

    let journalStore: LibraryMoveJournalStore
    let fileManager: FileManager
    let planner: LibraryMovePlanner
    let copier: LibraryMoveFileCopier
    /// Writes the setting that names the destination. `LibraryLocation.switchStored(to:)` in production.
    let switchLocation: @Sendable (LibraryLocation) throws -> Void

    public internal(set) var isRunning = false
    private let cancelFlag = CancelFlag()

    public init(journalStore: LibraryMoveJournalStore,
                fileManager: FileManager = .default,
                md5Provider: any MD5Provider = FileManager.default,
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                switchLocation: @escaping @Sendable (LibraryLocation) throws -> Void) {
        self.journalStore = journalStore
        self.fileManager = fileManager
        self.planner = planner
        self.copier = LibraryMoveFileCopier(fileManager: fileManager, md5Provider: md5Provider)
        self.switchLocation = switchLocation
    }

    /// Ask the running copy to stop. Honoured between files, only before the switch; a no-op afterwards.
    /// `nonisolated` so a progress callback (which runs on the engine) can call it synchronously.
    public nonisolated func cancel() {
        cancelFlag.set()
    }

    // MARK: - Start

    public func start(_ request: LibraryMoveRequest,
                      progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        guard Self.supportedMoves.contains([request.source, request.destination]) else {
            throw LibraryMoveError.unsupportedMove(from: request.source, to: request.destination)
        }
        // `exists` as well as `load()`: a journal from a newer build loads as nil but must not be overwritten.
        guard !isRunning, journalStore.load() == nil, !journalStore.exists else { throw LibraryMoveError.moveInProgress }
        try requireDistinctRoots(request.sourceRoot, request.destinationRoot, source: request.source, destination: request.destination)
        isRunning = true
        defer { isRunning = false }

        let plan = try planner.plan(root: request.sourceRoot, folders: request.folders)
        try planner.checkSpace(for: plan, at: request.destinationRoot)

        var journal = LibraryMoveJournal(request: request)
        try journalStore.save(journal)
        ILOG("LibraryMove: starting \(request.source.rawValue) → \(request.destination.rawValue): \(plan.items.count) files, \(plan.totalBytes) bytes")
        return try await run(&journal, plan: plan, sourceRoot: request.sourceRoot, destinationRoot: request.destinationRoot, progress: progress)
    }

    // MARK: - Resume

    /// Continues a journaled move. `copying` → finish the copy and switch. Anything later → cleanup.
    public func resume(_ journal: LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL,
                       progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        guard !isRunning else { throw LibraryMoveError.moveInProgress }
        try requireDistinctRoots(sourceRoot, destinationRoot, source: journal.source, destination: journal.destination)
        isRunning = true
        defer { isRunning = false }

        var journal = journal
        switch journal.phase {
        case .copying:
            let plan = try planner.plan(root: sourceRoot, folders: journal.folders)
            let remaining = plan.items.filter { journal.entries[$0.relativePath] == nil }
            try planner.checkSpace(for: LibraryMovePlan(items: remaining), at: destinationRoot)
            ILOG("LibraryMove: resuming copy, \(journal.entries.count) of \(plan.items.count) files already journaled")
            return try await run(&journal, plan: plan, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        case .switched, .cleaning:
            return try await cleanup(&journal, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        }
    }

    // MARK: - Copy phase

    private func run(_ journal: inout LibraryMoveJournal, plan: LibraryMovePlan, sourceRoot: URL, destinationRoot: URL,
                     progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> LibraryMoveOutcome {
        cancelFlag.reset()
        let copied = try await copyPhase(&journal, plan: plan, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        guard copied else {
            try rollback(journal, destinationRoot: destinationRoot)
            return .cancelled
        }
        try performSwitch(&journal)
        progress?(progressReport(journal, plan: plan, filesDone: plan.items.count, bytesDone: plan.totalBytes, current: nil))
        return .switched
    }

    /// Copies every planned file that the journal doesn't already record as intact at the destination.
    /// - Returns: `false` when cancelled (the caller rolls back).
    func copyPhase(_ journal: inout LibraryMoveJournal, plan: LibraryMovePlan, sourceRoot: URL, destinationRoot: URL,
                   progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> Bool {
        discardTornCopies(journal, destinationRoot: destinationRoot)

        var filesDone = 0
        var bytesDone: Int64 = 0
        var todo: [LibraryMovePlan.Item] = []
        for item in plan.items {
            if let existing = journal.entries[item.relativePath], destinationIntact(existing, relativePath: item.relativePath, destinationRoot: destinationRoot) {
                filesDone += 1
                bytesDone += existing.size
            } else {
                todo.append(item)
            }
        }

        var batchStart = 0
        while batchStart < todo.count {
            let batch = Array(todo[batchStart..<min(batchStart + Self.journalFlushInterval, todo.count)])
            batchStart += batch.count
            try claim(batch, in: &journal, destinationRoot: destinationRoot)

            for (index, item) in batch.enumerated() {
                if cancelFlag.isSet {
                    ILOG("LibraryMove: cancelled after \(filesDone) files")
                    return false
                }
                do {
                    if let entry = try copier.transfer(item, from: sourceRoot, to: destinationRoot, onConflict: .displaceExisting) {
                        journal.entries[item.relativePath] = entry
                        bytesDone += entry.size
                    }
                } catch {
                    // Keep what was verified so far: the next attempt resumes instead of recopying.
                    journal.updatedAt = Date()
                    try? journalStore.save(journal)
                    throw error
                }
                filesDone += 1
                if index == batch.count - 1 {
                    journal.updatedAt = Date()
                    try journalStore.save(journal)
                }
                progress?(progressReport(journal, plan: plan, filesDone: filesDone, bytesDone: bytesDone, current: item.relativePath))
                await Task.yield()
            }
        }
        journal.inFlight = []
        journal.updatedAt = Date()
        try journalStore.save(journal)
        return true
    }

    /// A journaled entry still holds: its destination file exists with the recorded size.
    private func destinationIntact(_ entry: LibraryMoveJournal.Entry, relativePath: String, destinationRoot: URL) -> Bool {
        let path = entry.destinationPath ?? relativePath
        return copier.verify(destinationRoot.appendingPathComponent(path), expectedSize: entry.size, expectedMD5: nil)
    }

    /// Records, in the journal and before any file is written, which destination paths and directories this batch
    /// will create. Only paths that don't exist yet are claimed, so a pre-existing destination file is never ours.
    /// A file that already exists at the destination is the destination's own: the copier may move it aside into
    /// `Conflicts/`, never delete it, so nothing is claimed for it (a claim makes a crash recovery delete the path).
    /// Only the directories the aside move would create are recorded.
    private func claim(_ batch: [LibraryMovePlan.Item], in journal: inout LibraryMoveJournal, destinationRoot: URL) throws {
        journal.inFlight = []
        for item in batch {
            var target = item.relativePath
            if exists(target, under: destinationRoot) {
                target = LibraryMoveFileCopier.conflictPath(for: item.relativePath, under: destinationRoot, fileManager: fileManager)
            } else {
                journal.inFlight.append(target)
            }
            for directory in missingDirectories(above: target, under: destinationRoot) where !journal.createdDirectories.contains(directory) {
                journal.createdDirectories.append(directory)
            }
        }
        journal.updatedAt = Date()
        try journalStore.save(journal)
    }

    /// Recovers from an interrupted run: removes every leftover temp file, then any file at a claimed path that no
    /// journal entry accounts for. Copies are renamed into place only after they verify, so such a file is a complete
    /// copy of ours that was never recorded; it is removed and copied again. Anything else in the destination,
    /// including a same-named file the user already had, is left alone.
    private func discardTornCopies(_ journal: LibraryMoveJournal, destinationRoot: URL) {
        removeStalePartials(under: destinationRoot, folders: journal.folders)
        let accountedFor = Set(journal.entries.map { $0.value.destinationPath ?? $0.key })
        for path in journal.inFlight where !accountedFor.contains(path) {
            let url = destinationRoot.appendingPathComponent(path)
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            WLOG("LibraryMove: removing unjournaled copy \(path)")
            try? fileManager.removeItem(at: url)
        }
    }

    /// Deletes the hidden temp files (`LibraryMoveFileCopier.partialSuffix`) an interrupted copy left under the
    /// destination's `folders`, `Conflicts/` and top level (where a loose file's temp file lives). Only the engine
    /// writes that suffix, and `isRunning` serialises the engine.
    func removeStalePartials(under root: URL, folders: [String]) {
        var candidates: [URL] = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for folder in Set(folders + [LibraryMoveFolders.conflicts]) {
            guard let enumerator = fileManager.enumerator(at: root.appendingPathComponent(folder, isDirectory: true), includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator {
                candidates.append(url)
            }
        }
        for url in candidates where url.lastPathComponent.hasSuffix(LibraryMoveFileCopier.partialSuffix) {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            WLOG("LibraryMove: removing leftover temp file \(url.lastPathComponent)")
            try? fileManager.removeItem(at: url)
        }
    }

    /// Roots that are the same folder, or one inside the other, would make every file "identical" (and cleanup would
    /// then delete the only copy) or have the copy enumerate its own output.
    private func requireDistinctRoots(_ sourceRoot: URL, _ destinationRoot: URL, source: LibraryLocation, destination: LibraryLocation) throws {
        let first = sourceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let second = destinationRoot.resolvingSymlinksInPath().standardizedFileURL.path
        guard first != second, !first.hasPrefix(second + "/"), !second.hasPrefix(first + "/") else {
            throw LibraryMoveError.unsupportedMove(from: source, to: destination)
        }
    }

    private func exists(_ relativePath: String, under root: URL) -> Bool {
        fileManager.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    /// The directories above `relativePath` (outermost first) that don't exist under `root`.
    private func missingDirectories(above relativePath: String, under root: URL) -> [String] {
        var missing: [String] = []
        var current = ""
        for component in relativePath.split(separator: "/").dropLast() {
            current = current.isEmpty ? String(component) : "\(current)/\(component)"
            if !exists(current, under: root) { missing.append(current) }
        }
        return missing
    }

    private func progressReport(_ journal: LibraryMoveJournal, plan: LibraryMovePlan, filesDone: Int, bytesDone: Int64, current: String?) -> LibraryMoveProgress {
        .init(phase: journal.phase, filesDone: filesDone, filesTotal: plan.items.count, bytesDone: bytesDone, bytesTotal: plan.totalBytes, currentPath: current)
    }

    // MARK: - Switch

    func performSwitch(_ journal: inout LibraryMoveJournal) throws {
        try switchLocation(journal.destination)
        journal.phase = .switched
        journal.updatedAt = Date()
        try journalStore.save(journal)
        ILOG("LibraryMove: switched to \(journal.destination.rawValue); cleanup runs at the next launch")
    }

    // MARK: - Rollback (cancel before switch)

    /// Deletes what this move put in the destination: `copied` files at their path, `conflict` copies at their
    /// `Conflicts/` path, and any claimed file no entry accounts for. A `displaced` entry loses our copy and gets the
    /// destination's own file back from `Conflicts/`. `identical` files pre-existed and stay, as does every directory
    /// the move did not create. Then the journal goes.
    func rollback(_ journal: LibraryMoveJournal, destinationRoot: URL) throws {
        for (relativePath, entry) in journal.entries where entry.state != .identical {
            if entry.state == .displaced {
                try restoreDisplaced(entry, relativePath: relativePath, under: destinationRoot)
            } else {
                try removeIfPresent(entry.destinationPath ?? relativePath, under: destinationRoot)
            }
        }
        let accountedFor = Set(journal.entries.map { $0.value.destinationPath ?? $0.key })
        for path in journal.inFlight where !accountedFor.contains(path) {
            try removeIfPresent(path, under: destinationRoot)
        }
        removeStalePartials(under: destinationRoot, folders: journal.folders)
        for directory in journal.createdDirectories.sorted(by: { $0.count > $1.count }) {
            let url = destinationRoot.appendingPathComponent(directory)
            if let contents = try? fileManager.contentsOfDirectory(atPath: url.path), contents.isEmpty {
                try fileManager.removeItem(at: url)
            }
        }
        try journalStore.delete()
    }

    /// Removes our copy at the real path and moves the destination's own file back over it from `Conflicts/`.
    /// Only acts while the aside file is still there: once it is back, the file at the real path is the user's and a
    /// retried rollback must not touch it.
    private func restoreDisplaced(_ entry: LibraryMoveJournal.Entry, relativePath: String, under root: URL) throws {
        guard let displacedPath = entry.displacedPath, exists(displacedPath, under: root) else {
            WLOG("LibraryMove: \(relativePath) has no displaced file to restore; leaving the real path alone")
            return
        }
        try removeIfPresent(relativePath, under: root)
        try fileManager.moveItem(at: root.appendingPathComponent(displacedPath), to: root.appendingPathComponent(relativePath))
    }

    private func removeIfPresent(_ relativePath: String, under root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { return }
        try fileManager.removeItem(at: url)
    }
}

/// Thread-safe cancel request, so `cancel()` can be called from any context without hopping onto the actor.
private final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var requested = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    func set() {
        lock.lock()
        requested = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        requested = false
        lock.unlock()
    }
}

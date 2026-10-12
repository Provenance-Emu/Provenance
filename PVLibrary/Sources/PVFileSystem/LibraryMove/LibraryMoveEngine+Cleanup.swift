//
//  LibraryMoveEngine+Cleanup.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The launch after the switch. The old process may have kept writing to the source until the
//  user relaunched, so first a delta sweep copies anything new or changed (a changed file goes to
//  Conflicts/, never over the verified copy), then every journaled source whose copy is still in
//  place is deleted (unless "keep a copy"), emptied folders are removed and the journal is dropped.
//  Idempotent: a crash mid-cleanup resumes here with the same journal. Not cancellable.
//

import Foundation
import PVLogging

extension LibraryMoveEngine {
    func cleanup(_ journal: inout LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL,
                 progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> LibraryMoveOutcome {
        if journal.phase != .cleaning {
            journal.phase = .cleaning
            journal.updatedAt = Date()
            try journalStore.save(journal)
        }

        removeStalePartials(under: destinationRoot, folders: journal.folders)
        try await sweepDelta(&journal, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)

        if journal.keepCopy {
            ILOG("LibraryMove: keeping a copy at the source as requested")
        } else {
            deleteSources(journal, sourceRoot: sourceRoot, destinationRoot: destinationRoot)
        }

        try journalStore.delete()
        progress?(.init(phase: .cleaning, filesDone: journal.entries.count, filesTotal: journal.entries.count, bytesDone: 0, bytesTotal: 0))
        return .cleanedUp
    }

    /// Size first; then modification time. The journal stores dates exactly, so the tolerance only absorbs
    /// floating-point noise: a rewrite a fraction of a second after the copy still counts as a change.
    static let modificationTolerance: TimeInterval = 0.001

    static func changedSinceJournal(_ item: LibraryMovePlan.Item, entry: LibraryMoveJournal.Entry) -> Bool {
        if item.size != entry.size { return true }
        guard let now = item.modified, let then = entry.modified else { return false }
        return abs(now.timeIntervalSince(then)) >= modificationTolerance
    }

    /// Copies whatever the source holds that the journal doesn't: new files go through the normal copy rules, changed
    /// files straight to `Conflicts/` (`transfer` would call a same-size file identical).
    private func sweepDelta(_ journal: inout LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL,
                            progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws {
        let plan = try planner.plan(root: sourceRoot, folders: journal.folders)
        let delta = plan.items.filter { item in
            journal.entries[item.relativePath].map { Self.changedSinceJournal(item, entry: $0) } ?? true
        }
        guard !delta.isEmpty else { return }

        ILOG("LibraryMove: delta sweep copying \(delta.count) files written after the switch")
        var swept = 0
        for item in delta {
            let entry: LibraryMoveJournal.Entry?
            if journal.entries[item.relativePath] == nil {
                entry = try copier.transfer(item, from: sourceRoot, to: destinationRoot)
            } else {
                entry = try copier.transferAsConflict(item, from: sourceRoot, to: destinationRoot)
            }
            if let entry {
                journal.entries[item.relativePath] = entry
            }
            swept += 1
            progress?(.init(phase: .cleaning, filesDone: swept, filesTotal: delta.count, bytesDone: 0, bytesTotal: 0, currentPath: item.relativePath))
            await Task.yield()
        }
        journal.updatedAt = Date()
        try journalStore.save(journal)
    }

    /// Deletes each journaled source whose verified copy is still at the destination, then the folders that emptied.
    /// A source whose copy has gone missing is kept: it is the only one left.
    private func deleteSources(_ journal: LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL) {
        var deleted = 0
        for (relativePath, entry) in journal.entries {
            let source = sourceRoot.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let copy = destinationRoot.appendingPathComponent(entry.destinationPath ?? relativePath)
            guard copier.verify(copy, expectedSize: entry.size, expectedMD5: nil) else {
                WLOG("LibraryMove: keeping \(relativePath): its copy is missing from the destination")
                continue
            }
            do {
                try fileManager.removeItem(at: source)
                deleted += 1
            } catch {
                WLOG("LibraryMove: could not delete \(relativePath): \(error.localizedDescription)")
            }
        }
        removeEmptyDirectories(under: sourceRoot, folders: journal.folders)
        ILOG("LibraryMove: deleted \(deleted) source files")
    }

    /// Removes now-empty directories below `root/<folder>` bottom-up, then the folder itself if it is empty.
    private func removeEmptyDirectories(under root: URL, folders: [String]) {
        for folder in folders {
            let top = root.appendingPathComponent(folder, isDirectory: true)
            guard let enumerator = fileManager.enumerator(at: top, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            var directories: [URL] = []
            for case let url as URL in enumerator where (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                directories.append(url)
            }
            for directory in (directories + [top]).sorted(by: { $0.path.count > $1.path.count }) {
                if let contents = try? fileManager.contentsOfDirectory(atPath: directory.path), contents.isEmpty {
                    try? fileManager.removeItem(at: directory)
                }
            }
        }
    }
}

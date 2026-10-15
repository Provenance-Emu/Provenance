//
//  MultiFileImportGate.swift
//  PVLibrary
//
//  Sits between the import folder's watcher and the importer. Files handed over
//  one at a time (a sibling app's share sheet sends a .gdi, then each track) are
//  held until their set is complete, fixed up, and released together.
//  The rule itself is `MultiFileImportSettler` (pure, tested); this actor reads the
//  folder, applies the fix-ups and runs the timer.
//

import Foundation
import PVLogging

public actor MultiFileImportGate {

    public typealias Release = @Sendable ([URL]) async -> Void

    private let directory: URL
    private let policy: MultiFileImportSettlePolicy
    /// While the watcher is still waiting for a file to finish copying, nothing is decided,
    /// for at most this long after the last arrival.
    private let busyLimit: TimeInterval
    private let isBusy: @Sendable () async -> Bool
    private let release: Release

    /// Waiting files in arrival order.
    private var pending: [String] = []
    /// Files already released that are still in the folder (the watcher reports them again on every change).
    private var released: Set<String> = []
    private var lastArrival = Date.distantPast
    /// Only the newest scheduled check runs; older ones see a stale generation and stop.
    /// (Not cancellation: a cancelled task would also cancel the import it releases into.)
    private var generation = 0
    private var isScheduled = false

    public init(
        directory: URL,
        policy: MultiFileImportSettlePolicy = MultiFileImportSettlePolicy(),
        busyLimit: TimeInterval = 60,
        isBusy: @escaping @Sendable () async -> Bool,
        release: @escaping Release
    ) {
        self.directory = directory.standardizedFileURL
        self.policy = policy
        self.busyLimit = busyLimit
        self.isBusy = isBusy
        self.release = release
    }

    /// Hands files to the gate. Anything not directly inside the import folder, and folders,
    /// pass straight through; files in it wait for the settle rule.
    public func submit(_ urls: [URL]) async {
        var passThrough: [URL] = []
        var arrived = false
        for url in urls {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard exists, !isDirectory.boolValue,
                  url.deletingLastPathComponent().standardizedFileURL.path == directory.path else {
                passThrough.append(url)
                continue
            }
            let key = url.lastPathComponent.lowercased()
            guard !released.contains(key), !pending.contains(where: { $0.lowercased() == key }) else { continue }
            pending.append(url.lastPathComponent)
            arrived = true
        }
        if arrived {
            lastArrival = Date()
            schedule(after: policy.quietWindow)
        }
        if !passThrough.isEmpty {
            await release(passThrough)
        }
    }

    // MARK: - Evaluation

    private func schedule(after delay: TimeInterval) {
        generation += 1
        isScheduled = true
        let scheduled = generation
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(delay, 0.1) * 1_000_000_000))
            await self?.evaluate(generation: scheduled)
        }
    }

    private func evaluate(generation scheduled: Int) async {
        guard scheduled == generation else { return }
        isScheduled = false
        let present = presentFiles()
        let presentKeys = Set(present.map { $0.lowercased() })
        released = released.filter { presentKeys.contains($0) }
        pending.removeAll { !presentKeys.contains($0.lowercased()) }
        guard !pending.isEmpty else { return }

        let quiet = Date().timeIntervalSince(lastArrival)
        if quiet < policy.quietWindow {
            schedule(after: policy.quietWindow - quiet)
            return
        }
        if quiet < busyLimit, await isBusy() {
            schedule(after: 1)
            return
        }

        let fixups = MultiFileImportSettler.fixups(for: snapshot(present: present, quiet: quiet), policy: policy)
        if !fixups.isEmpty {
            apply(fixups)
        }

        let decision = MultiFileImportSettler.decide(snapshot(present: presentFiles(), quiet: quiet), policy: policy)
        if !decision.release.isEmpty {
            let keys = Set(decision.release.map { $0.lowercased() })
            pending.removeAll { keys.contains($0.lowercased()) }
            released.formUnion(keys)
            ILOG("MultiFileImportGate: releasing \(decision.release.joined(separator: ", "))")
            await release(decision.release.map { directory.appendingPathComponent($0, isDirectory: false) })
        }
        if !decision.hold.isEmpty {
            ILOG("MultiFileImportGate: holding \(decision.hold.joined(separator: ", ")) for missing files")
        }
        if let recheck = decision.recheckAfter, !isScheduled {
            schedule(after: recheck)
        }
    }

    private func snapshot(present: [String], quiet: TimeInterval) -> MultiFileImportSnapshot {
        var contents: [String: String] = [:]
        for name in present where MultiFileIndexKind(fileName: name) != nil {
            let url = directory.appendingPathComponent(name, isDirectory: false)
            contents[name] = try? DefaultCDFileHandler.readIndexText(at: url)
        }
        return MultiFileImportSnapshot(
            pending: pending,
            present: present,
            indexContents: contents,
            secondsSinceLastArrival: quiet
        )
    }

    /// Regular files at the top of the import folder (hidden ones, partial copies included, skipped).
    private func presentFiles() -> [String] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        return items
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map(\.lastPathComponent)
    }

    private func apply(_ fixups: [MultiFileImportFixup]) {
        let fileManager = FileManager.default
        for fixup in fixups {
            switch fixup {
            case let .rename(from, to):
                let source = directory.appendingPathComponent(from, isDirectory: false)
                let destination = directory.appendingPathComponent(to, isDirectory: false)
                do {
                    try fileManager.moveItem(at: source, to: destination)
                    if let index = pending.firstIndex(of: from) { pending[index] = to }
                    ILOG("MultiFileImportGate: renamed \(from) back to \(to)")
                } catch {
                    WLOG("MultiFileImportGate: could not rename \(from) to \(to): \(error.localizedDescription)")
                }

            case let .rewriteReference(indexFile, from, to):
                let url = directory.appendingPathComponent(indexFile, isDirectory: false)
                do {
                    try DefaultCDFileHandler().rewriteReference(inIndexFileAt: url, from: from, to: to)
                } catch {
                    WLOG("MultiFileImportGate: could not point \(indexFile) at \(to): \(error.localizedDescription)")
                }

            case let .nestCompanion(file, archive):
                let source = directory.appendingPathComponent(file, isDirectory: false)
                let staging = ArchiveCompanionLayout.stagingDirectory(importDirectory: directory, archiveName: archive)
                let destination = staging.appendingPathComponent(file, isDirectory: false)
                do {
                    try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
                    if fileManager.fileExists(atPath: destination.path) {
                        try fileManager.removeItem(at: destination)
                    }
                    try fileManager.moveItem(at: source, to: destination)
                    pending.removeAll { $0 == file }
                    ILOG("MultiFileImportGate: \(file) goes with \(archive) as \(ArchiveCompanionLayout.relativePath(archiveName: archive, companionName: file))")
                } catch {
                    WLOG("MultiFileImportGate: could not stage \(file) for \(archive): \(error.localizedDescription)")
                }
            }
        }
    }
}

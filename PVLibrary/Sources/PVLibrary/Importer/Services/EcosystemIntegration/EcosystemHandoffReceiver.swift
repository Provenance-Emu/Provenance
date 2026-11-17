//
//  EcosystemHandoffReceiver.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVFileSystem
import PVLogging

/// Runs Provenance's side of the shared drop box (see `EcosystemHandoff`) when the
/// app comes to the front: publishes the presence entry that tells iFly and iCube
/// to send games directly, takes the hand-offs waiting for Provenance, and
/// removes Provenance's own sends nobody picked up (`EcosystemHandoffStager`).
///
/// Everything runs on one serial queue, so a launch, a scene activation and a
/// `provenance://handoff` URL arriving together drain the inbox one after the
/// other (the second finds it empty), and a multi-gigabyte copy across volumes
/// never holds a Swift concurrency thread.
public final class EcosystemHandoffReceiver: @unchecked Sendable {
    public static let shared = EcosystemHandoffReceiver()

    /// What happened to one hand-off.
    public enum Outcome: Equatable, Sendable {
        case received(EcosystemHandoffManifest, EcosystemHandoffInbox.Placement)
        case refused(EcosystemHandoffManifest, EcosystemHandoffInbox.Refusal)
        case failed(EcosystemHandoffManifest, message: String)
    }

    private let queue = DispatchQueue(label: "org.provenance-emu.ecosystem-handoff", qos: .utility)
    private let rootProvider: @Sendable () -> URL?
    private let importDirectoryProvider: @Sendable () -> URL
    private let fileManager: FileManager
    /// Hand-offs already reported as refused in this process (queue-confined), so
    /// one the sender has yet to clean up is not reported on every activation.
    private var reportedRefusals = Set<String>()

    public init(
        root: @escaping @Sendable () -> URL? = { EcosystemHandoff.sharedRoot },
        importDirectory: @escaping @Sendable () -> URL = { Paths.romsImportPath },
        fileManager: FileManager = .default
    ) {
        self.rootProvider = root
        self.importDirectoryProvider = importDirectory
        self.fileManager = fileManager
    }

    /// Launch and every scene activation: rewrite the presence entry, take
    /// whatever is waiting, then clear out stale sends of our own.
    public func appBecameActive() {
        queue.async { [self] in
            publishPresenceNow()
            postOutcomes(receivePendingNow())
            collectGarbageNow()
        }
    }

    /// A sender opened `provenance://handoff`: take whatever is waiting.
    public func receivePending() {
        queue.async { [self] in
            postOutcomes(receivePendingNow())
        }
    }

    // MARK: - Synchronous work (the queue, or a test)

    func publishPresenceNow(now: Date = Date(), bundle: Bundle = .main) {
        guard let root = rootProvider() else {
            WLOG("Ecosystem: no App Group container; sibling apps can't hand games to this build")
            return
        }
        do {
            try EcosystemPresence.own(now: now, bundle: bundle).write(root: root, fileManager: fileManager)
        } catch {
            WLOG("Ecosystem: couldn't write presence: \(error.localizedDescription)")
        }
    }

    /// Removes Provenance's hand-offs nobody picked up within a week and staging
    /// directories of sends that died.
    @discardableResult
    func collectGarbageNow(now: Date = Date()) -> Int {
        guard let root = rootProvider() else { return 0 }
        let removed = EcosystemHandoffStager.collectGarbage(root: root, now: now, fileManager: fileManager)
        if removed > 0 {
            ILOG("Ecosystem: removed \(removed) stale hand-off(s) nobody picked up")
        }
        return removed
    }

    func receivePendingNow() -> [Outcome] {
        guard let root = rootProvider() else { return [] }
        let importDirectory = importDirectoryProvider()
        let pending = EcosystemHandoffInbox.pending(root: root, fileManager: fileManager)
        guard !pending.isEmpty else { return [] }

        ILOG("Ecosystem: \(pending.count) hand-off(s) waiting in the drop box")
        do {
            try fileManager.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        } catch {
            ELOG("Ecosystem: couldn't create \(importDirectory.path): \(error.localizedDescription)")
            return []
        }
        EcosystemHandoffInbox.removeLeftoverStaging(in: importDirectory, fileManager: fileManager)

        var outcomes: [Outcome] = []
        for item in pending {
            let manifest = item.manifest
            let id = item.directory.lastPathComponent
            do {
                let placement = try EcosystemHandoffInbox.place(item, into: importDirectory, fileManager: fileManager)
                ILOG("Ecosystem: received '\(manifest.title)' from \(manifest.from):// → "
                     + placement.imported.map(\.lastPathComponent).joined(separator: ", "))
                outcomes.append(.received(manifest, placement))
            } catch let refusal as EcosystemHandoffInbox.Refusal {
                guard reportedRefusals.insert(id).inserted else { continue }
                WLOG("Ecosystem: refused hand-off '\(manifest.title)' (\(id)) from \(manifest.from)://: \(refusal)")
                outcomes.append(.refused(manifest, refusal))
            } catch {
                ELOG("Ecosystem: couldn't place hand-off '\(manifest.title)' (\(id)): \(error.localizedDescription)")
                outcomes.append(.failed(manifest, message: error.localizedDescription))
            }
        }
        return outcomes
    }

    private func postOutcomes(_ outcomes: [Outcome]) {
        guard !outcomes.isEmpty else { return }
        DispatchQueue.main.async {
            for outcome in outcomes {
                switch outcome {
                case let .received(manifest, placement):
                    NotificationCenter.default.post(
                        name: .ecosystemHandoffReceived,
                        object: nil,
                        userInfo: [
                            "source": manifest.from.lowercased(),
                            "name": manifest.title,
                            "paths": placement.imported.map(\.path)
                        ])
                case let .refused(manifest, refusal):
                    NotificationCenter.default.post(
                        name: .ecosystemHandoffFailed,
                        object: nil,
                        userInfo: ["source": manifest.from.lowercased(), "name": manifest.title, "error": "\(refusal)"])
                case let .failed(manifest, message):
                    NotificationCenter.default.post(
                        name: .ecosystemHandoffFailed,
                        object: nil,
                        userInfo: ["source": manifest.from.lowercased(), "name": manifest.title, "error": message])
                }
            }
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    /// An ecosystem app answered a gameInfo query.
    /// userInfo: `source` (EcosystemApp raw value), `games` ([EcosystemGameScheme]).
    static let ecosystemGamesReceived = Notification.Name("PVEcosystemGamesReceived")
    /// A sibling app's hand-off is in the import folder. Posted on the main thread.
    /// userInfo: `source` (sender scheme, an EcosystemApp raw value for iFly and
    /// iCube), `name` (title), `paths` ([String], what the watcher will import).
    static let ecosystemHandoffReceived = Notification.Name("PVEcosystemHandoffReceived")
    /// A sibling app's hand-off was refused or could not be placed. Posted on the
    /// main thread. userInfo: `source`, `name`, `error`.
    static let ecosystemHandoffFailed = Notification.Name("PVEcosystemHandoffFailed")
}

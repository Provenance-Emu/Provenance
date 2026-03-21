//
//  BackupCoordinator.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Singleton coordinator for backup/restore that outlives any individual view,
//  so compression continues even after the user dismisses BackupRestoreView.
//

import Foundation
import Combine

// MARK: - BackupCoordinator

/// Persistent singleton that drives backup and restore operations.
///
/// The coordinator is `@MainActor` so all `@Published` mutations are on the
/// main thread. The actual file-I/O work runs on a detached task so it never
/// blocks the main actor.
@MainActor
public final class BackupCoordinator: ObservableObject {

    public static let shared = BackupCoordinator()
    private init() {}

    // MARK: - Published state

    @Published public private(set) var backupState: BackupViewState = .idle
    @Published public private(set) var restoreState: RestoreViewState = .idle
    /// URL of the finished backup archive, valid while `backupState == .done`.
    @Published public private(set) var backupURL: URL? = nil

    // MARK: - Private

    private var currentBackupTask: Task<Void, Never>?

    // MARK: - Backup

    /// Starts a backup. Compression runs on a background thread and the task
    /// is owned by the coordinator, so it survives view dismissal.
    public func startBackup(contents: BackupContents) {
        currentBackupTask?.cancel()
        backupState = .inProgress(.preparing)

        // Task.detached so file-I/O (especially SSZipArchive) runs off main actor
        currentBackupTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let url = try await BackupManager.shared.createBackup(
                    contents: contents,
                    progressHandler: { phase in
                        Task { @MainActor [weak self] in
                            self?.backupState = .inProgress(phase)
                        }
                    }
                )
                await MainActor.run { [weak self] in
                    self?.backupURL = url
                    self?.backupState = .done
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.backupState = .error(error.localizedDescription)
                }
            }
        }
    }

    /// Cleans up the finished backup file and resets state to `.idle`.
    /// Call this after the share sheet has been dismissed.
    public func cleanupAfterShare() {
        if let url = backupURL {
            BackupManager.shared.cleanupBackup(at: url)
            backupURL = nil
        }
        backupState = .idle
    }

    /// Cancels any in-progress backup and resets to `.idle`.
    public func cancelBackup() {
        currentBackupTask?.cancel()
        currentBackupTask = nil
        if let url = backupURL {
            BackupManager.shared.cleanupBackup(at: url)
            backupURL = nil
        }
        backupState = .idle
    }

    // MARK: - Restore

    /// Starts a restore. Runs on a background task owned by the coordinator.
    public func startRestore(from url: URL, contents: BackupContents) {
        restoreState = .inProgress(.restoring)

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let restored = try await BackupManager.shared.restoreBackup(
                    from: url,
                    contents: contents,
                    progressHandler: { phase in
                        Task { @MainActor [weak self] in
                            self?.restoreState = .inProgress(phase)
                        }
                    }
                )
                await MainActor.run { [weak self] in
                    self?.restoreState = .done(restored)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.restoreState = .error(error.localizedDescription)
                }
            }
        }
    }

    public func resetRestoreState() {
        restoreState = .idle
    }
}

//
//  SystemDirectoryMigration.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-29.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  One-time migration that moves legacy system directories from the flat
//  Documents root into the canonical `Documents/System/<name>/` hierarchy
//  introduced in version 3564.
//
//  Mapping table (legacy → canonical):
//    Documents/PSP/                → Documents/System/PSP/
//    Documents/com.provenance.n64/ → Documents/Battery States/com.provenance.n64/
//    Documents/RetroArch/system/*  → Documents/System/  (contents merged)
//    Documents/nand/               → Documents/System/3DS/nand/
//    Documents/sdmc/               → Documents/System/3DS/sdmc/
//    Documents/sysdata/            → Documents/System/3DS/sysdata/
//    Documents/Play Data Files/    → Documents/System/PS2/
//
//  Safety guarantees:
//  - Idempotent: guarded by a `UserDefaults` flag; runs at most once per device.
//  - Non-destructive: source directories are removed only after all items
//    have been successfully moved; original data is never deleted on error.
//  - Per-file: items are moved individually so a partial failure doesn't
//    corrupt already-migrated files.
//  - Progress: callers may pass a `progressHandler` closure to receive live
//    ``SystemDirectoryMigrationStep`` updates.
//

import Foundation
import PVLogging
import PVFileSystem

// MARK: - Public types

/// Errors that ``SystemDirectoryMigration`` can surface.
public enum SystemDirectoryMigrationError: Error, LocalizedError {
    /// The destination directory could not be created.
    case destinationCreationFailed(path: String, underlying: Error)
    /// A source item could not be moved to its destination.
    case moveItemFailed(source: String, destination: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .destinationCreationFailed(let path, let underlying):
            return "Failed to create destination directory '\(path)': \(underlying.localizedDescription)"
        case .moveItemFailed(let src, let dst, let underlying):
            return "Failed to move '\(src)' to '\(dst)': \(underlying.localizedDescription)"
        }
    }
}

/// A single step reported during migration.
public struct SystemDirectoryMigrationStep: Sendable {
    /// Human-readable description of the step.
    public let description: String
    /// Number of items moved so far across all steps.
    public let itemsMoved: Int
}

// MARK: - Migration actor

/// One-time migration of legacy flat-Documents system directories into
/// `Documents/System/<name>/` (and related canonical paths).
///
/// Call ``migrateIfNeeded()`` once on app launch (on a background task).
/// The migration records its completion in `UserDefaults` and will not
/// re-run on subsequent launches.
///
/// ```swift
/// Task.detached(priority: .utility) {
///     let migration = SystemDirectoryMigration()
///     try? await migration.migrateIfNeeded()
/// }
/// ```
public actor SystemDirectoryMigration {

    // MARK: - Constants

    /// `UserDefaults` key written after a successful migration.
    /// Exposed as `internal` so tests can reference the key without hard-coding it.
    static let migrationCompletedKey = "PVSystemDirectoryMigrationCompleted"

    // MARK: - Properties

    private let defaults: UserDefaults
    /// Root of the legacy flat layout.  Defaults to `URL.documentsPath`.
    /// Override in tests to point at a temporary directory.
    private let documentsRoot: URL

    // MARK: - Init

    /// Creates a migrator.
    ///
    /// - Parameters:
    ///   - defaults: Defaults store used to track completion (default: `.standard`).
    ///   - documentsRoot: The directory that contains the legacy paths to migrate.
    ///     Defaults to `URL.documentsPath`.  Pass a temporary directory in tests.
    public init(
        defaults: UserDefaults = .standard,
        documentsRoot: URL = URL.documentsPath
    ) {
        self.defaults = defaults
        self.documentsRoot = documentsRoot
    }

    // MARK: - Public API

    /// `true` when the migration has already been recorded as complete.
    public var isMigrationCompleted: Bool {
        defaults.bool(forKey: Self.migrationCompletedKey)
    }

    /// Runs the migration unless it has already completed.
    ///
    /// - Parameter progressHandler: Optional closure called after each item is moved.
    ///   The closure is called on an unspecified execution context.
    /// - Throws: ``SystemDirectoryMigrationError`` if a destination directory cannot
    ///   be created or an item cannot be moved.  Errors from individual file moves are
    ///   logged and accumulated; the first error is re-thrown after all items have
    ///   been attempted.
    public func migrateIfNeeded(
        progressHandler: (@Sendable (SystemDirectoryMigrationStep) -> Void)? = nil
    ) async throws {
        guard !isMigrationCompleted else {
            ILOG("[SystemDirMigration] Already completed — skipping.")
            return
        }

        ILOG("[SystemDirMigration] Starting legacy system-directory migration.")
        try await runMigration(progressHandler: progressHandler)
        defaults.set(true, forKey: Self.migrationCompletedKey)
        ILOG("[SystemDirMigration] Migration complete.")
    }

    /// Clears the completion flag so ``migrateIfNeeded()`` will re-run.
    /// Intended for debugging / testing only.
    internal func resetMigrationFlag() {
        defaults.removeObject(forKey: Self.migrationCompletedKey)
        ILOG("[SystemDirMigration] Reset migration flag.")
    }

    // MARK: - Internal: migration runner

    private func runMigration(
        progressHandler: (@Sendable (SystemDirectoryMigrationStep) -> Void)?
    ) async throws {
        let docs = documentsRoot
        // Canonical destinations are always relative to the same root so that
        // both production (real Documents/) and tests (temp dir) work uniformly.
        let systemRoot = docs.appendingPathComponent("System")
        let batteryRoot = docs.appendingPathComponent("Battery States")

        var totalMoved = 0
        var firstError: Error?

        // ---------------------------------------------------------------
        // Helper: merge all items from `source` into `destination`.
        // Removes the (now-empty) source directory on full success.
        // ---------------------------------------------------------------
        func mergeDirectory(from source: URL, into destination: URL, stepLabel: String) {
            let fm = FileManager.default
            guard fm.fileExists(atPath: source.path) else { return }

            do {
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            } catch {
                ELOG("[SystemDirMigration] Cannot create destination '\(destination.path)': \(error)")
                if firstError == nil {
                    firstError = SystemDirectoryMigrationError.destinationCreationFailed(
                        path: destination.path, underlying: error)
                }
                return
            }

            let items: [URL]
            do {
                items = try fm.contentsOfDirectory(
                    at: source, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } catch {
                ELOG("[SystemDirMigration] Cannot list '\(source.path)': \(error)")
                return
            }

            for item in items {
                let dest = destination.appendingPathComponent(item.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    WLOG("[SystemDirMigration] Skipping '\(item.lastPathComponent)' — already at destination.")
                    continue
                }
                do {
                    try fm.moveItem(at: item, to: dest)
                    totalMoved += 1
                    progressHandler?(.init(description: stepLabel, itemsMoved: totalMoved))
                } catch {
                    ELOG("[SystemDirMigration] Move failed '\(item.path)' → '\(dest.path)': \(error)")
                    if firstError == nil {
                        firstError = SystemDirectoryMigrationError.moveItemFailed(
                            source: item.path, destination: dest.path, underlying: error)
                    }
                }
            }

            // Remove the now-empty source directory.
            let remaining = (try? fm.contentsOfDirectory(atPath: source.path)) ?? []
            if remaining.isEmpty {
                try? fm.removeItem(at: source)
            }
        }

        // 1. Documents/PSP/ → Documents/System/PSP/
        mergeDirectory(
            from: docs.appendingPathComponent("PSP"),
            into: systemRoot.appendingPathComponent("PSP"),
            stepLabel: "PSP system directory"
        )

        // 2. Documents/com.provenance.n64/ → Documents/Battery States/com.provenance.n64/
        mergeDirectory(
            from: docs.appendingPathComponent("com.provenance.n64"),
            into: batteryRoot.appendingPathComponent("com.provenance.n64"),
            stepLabel: "N64 battery saves"
        )

        // 3. Documents/RetroArch/system/* → Documents/System/
        mergeDirectory(
            from: docs.appendingPathComponent("RetroArch/system"),
            into: systemRoot,
            stepLabel: "RetroArch system directory"
        )

        // 4. Documents/nand/, sdmc/, sysdata/ → Documents/System/3DS/<name>/
        let threeDSRoot = systemRoot.appendingPathComponent("3DS")
        for legacyName in ["nand", "sdmc", "sysdata"] {
            mergeDirectory(
                from: docs.appendingPathComponent(legacyName),
                into: threeDSRoot.appendingPathComponent(legacyName),
                stepLabel: "3DS \(legacyName)"
            )
        }

        // 5. Documents/Play Data Files/ → Documents/System/PS2/
        mergeDirectory(
            from: docs.appendingPathComponent("Play Data Files"),
            into: systemRoot.appendingPathComponent("PS2"),
            stepLabel: "PS2 Play Data Files"
        )

        ILOG("[SystemDirMigration] Moved \(totalMoved) item(s) in total.")
        if let err = firstError { throw err }
    }
}

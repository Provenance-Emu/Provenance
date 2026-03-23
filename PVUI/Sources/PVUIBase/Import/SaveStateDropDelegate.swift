//
//  SaveStateDropDelegate.swift
//  PVUI
//
//  Created by Agent on 2026-03-22.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Implements drag & drop import of save bundles and battery save files onto game cards.
//  Part of issue #3408 (per-game save export via share sheet + drag from save browser).
//
//  iOS / macCatalyst only — onDrop is unavailable on tvOS.
//

#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import PVLibrary
import PVRealm
import PVLogging
import PVFileSystem

// MARK: - Accepted types

/// UTTypes accepted by the save-state drop target.
/// Covers our zip bundles and explicit file URLs dragged from Files.app (e.g. `.sav`/`.srm` files).
private let saveDropAcceptedTypes: [UTType] = [
    .zip,
    .fileURL,
]

// MARK: - ViewModifier

/// Attaches a save-state/bundle drop target to a game card.
///
/// Accepted payloads:
/// - **`.zip`** export bundles created by `SaveExporter` — imported via `SaveExporter.importSaves(from:for:)`,
///   which validates the MD5 manifest before restoring files.
/// - **`.sav` / `.srm`** battery save files — copied directly to the game's battery saves directory.
///
/// Neither path registers new `PVSaveState` objects in Realm; a library re-scan or relaunch
/// will surface the restored states in the UI. See issue #3409 for the Realm registration follow-up.
public struct SaveStateDropTargetModifier: ViewModifier {
    /// The Realm primary key of the game this drop target belongs to.
    /// This is `PVGame.md5Hash` — **not** `PVGame.id` (UUID-formatted string).
    let gameId: String

    @State private var isTargeted = false

    public init(gameId: String) {
        self.gameId = gameId
    }

    public func body(content: Content) -> some View {
        content
            .onDrop(of: saveDropAcceptedTypes, isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: isTargeted ? 3 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
                    .allowsHitTesting(false)
            )
    }

    // MARK: - Drop handling

    @discardableResult
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        var handled = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
                    if let error { ELOG("SaveStateDropDelegate: loadFileRepresentation(fileURL) error: \(error)"); return }
                    guard let url else { return }
                    do {
                        let stableURL = try Self.stableCopy(of: url)
                        processDroppedFile(stableURL)
                    } catch {
                        ELOG("SaveStateDropDelegate: stableCopy(fileURL) error: \(error)")
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.zip.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.zip.identifier) { url, error in
                    if let error { ELOG("SaveStateDropDelegate: loadFileRepresentation(zip) error: \(error)"); return }
                    guard let url else { return }
                    do {
                        let stable = try Self.stableCopy(of: url)
                        processDroppedFile(stable)
                    } catch {
                        ELOG("SaveStateDropDelegate: stableCopy(zip) error: \(error)")
                    }
                }
                handled = true
            }
        }

        return handled
    }

    // MARK: - Per-file dispatch

    private func processDroppedFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "zip":
            importBundle(zipURL: url)
        case "sav", "srm", "ram":
            importBatterySave(fileURL: url)
        default:
            WLOG("SaveStateDropDelegate: Unsupported file extension '\(ext)' — ignoring drop.")
            // Clean up the temp copy created by stableCopy(of:) to avoid leaking storage.
            let tempDir = url.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Bundle import (zip)

    private func importBundle(zipURL: URL) {
        Task { @MainActor in
            let tempDir = zipURL.deletingLastPathComponent()
            guard let game = RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: gameId) else {
                ELOG("SaveStateDropDelegate: Game not found for id: \(gameId)")
                try? FileManager.default.removeItem(at: tempDir)
                return
            }
            do {
                try await SaveExporter.shared.importSaves(from: zipURL, for: game)
                ILOG("SaveStateDropDelegate: Bundle import succeeded for '\(game.title)'")
            } catch {
                ELOG("SaveStateDropDelegate: Bundle import failed: \(error.localizedDescription)")
            }
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Battery save import (.sav / .srm / .ram)

    private func importBatterySave(fileURL: URL) {
        Task {
            let tempDir = fileURL.deletingLastPathComponent()
            guard let romURL = await MainActor.run(body: {
                RomDatabase.sharedInstance
                    .object(ofType: PVGame.self, wherePrimaryKeyEquals: gameId)?
                    .file?
                    .url
            }) else {
                ELOG("SaveStateDropDelegate: Game \(gameId) has no ROM URL — cannot import battery save.")
                try? FileManager.default.removeItem(at: tempDir)
                return
            }

            let destDir = Paths.batterySavesPath(forROM: romURL)
            let destURL = destDir.appendingPathComponent(fileURL.lastPathComponent)
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
                try fm.copyItem(at: fileURL, to: destURL)
                ILOG("SaveStateDropDelegate: Battery save imported to \(destURL.path)")
            } catch {
                ELOG("SaveStateDropDelegate: Failed to import battery save: \(error.localizedDescription)")
            }
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Helpers

    private static func stableCopy(of sourceURL: URL) throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVSaveDropImports", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let uniqueDir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: uniqueDir, withIntermediateDirectories: true)
        let dest = uniqueDir.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }
}

// MARK: - View extension

public extension View {
    /// Attaches a save-state/bundle drop target to a game card.
    ///
    /// Accepts export zip bundles and `.sav`/`.srm` battery save files.
    /// iOS / macCatalyst only.
    ///
    /// - Parameter gameId: `PVGame.md5Hash` — the Realm primary key. Do **not** pass `PVGame.id` (UUID string).
    func saveStateDropTarget(gameId: String) -> some View {
        modifier(SaveStateDropTargetModifier(gameId: gameId))
    }
}
#endif // os(iOS)

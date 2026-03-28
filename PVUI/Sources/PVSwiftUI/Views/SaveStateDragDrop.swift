//
//  SaveStateDragDrop.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-22.
//  Copyright 2026 Provenance Emu. All rights reserved.
//
//  NSItemProvider-based drag-source for individual save state files,
//  and a drop target that imports `.zip` save-export bundles created by `SaveExporter`.
//
//  Part of issue #2136: Add Drag & Drop support to library, saves etc.
//
//  iOS/iPadOS/macCatalyst only — drag and drop APIs are unavailable on tvOS.
//

#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import PVLibrary
import PVLogging
import PVRealm
import RealmSwift

// MARK: - Save State Drag Source

/// Modifier that makes a save-state row draggable.
///
/// The drag provides the on-disk `.svs` / `.state` save-state file as a
/// `public.file-url`, allowing users to drop it into the Files app, AirDrop
/// it to another device, or share it with any file-compatible app.
public struct SaveStateDragModifier: ViewModifier {
    /// Realm primary key of `PVSaveState`.
    let saveStateID: String

    public init(saveStateID: String) {
        self.saveStateID = saveStateID
    }

    public func body(content: Content) -> some View {
        content
            .onDrag {
                makeItemProvider()
            }
    }

    private func makeItemProvider() -> NSItemProvider {
        // Resolve the URL now, on the main thread (called from .onDrag).
        guard let fileURL = Self.resolveFileURL(forSaveStateID: saveStateID) else {
            WLOG("SaveStateDragDrop: no on-disk file found for save state \(saveStateID)")
            return NSItemProvider()
        }
        // Vend via NSURL for better cross-app drag-out compatibility.
        if let provider = NSItemProvider(contentsOf: fileURL) {
            return provider
        }
        return NSItemProvider(object: fileURL as NSURL)
    }

    private static func resolveFileURL(forSaveStateID id: String) -> URL? {
        guard let state = RomDatabase.sharedInstance.object(
            ofType: PVSaveState.self,
            wherePrimaryKeyEquals: id
        ),
        let url = state.file?.url,
        FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
}

// MARK: - Save Bundle Drop Target

/// Accepted UTTypes for save-bundle drop target.
/// We accept .pvsave bundles (v2), legacy .zip bundles (v1), and explicit file URLs.
private let saveBundleAcceptedTypes: [UTType] = [
    UTType(exportedAs: "com.provenance.pvsave", conformingTo: .zip),
    UTType(filenameExtension: "pvsave") ?? .data,
    UTType(filenameExtension: "zip") ?? .data,
    .fileURL,
    .data,
]

/// Result feedback from a save-bundle import.
public enum SaveBundleDropResult {
    case success(gameTitle: String)
    case failure(Error)
    case missingGame
}

/// Modifier that accepts dropped `.zip` save-export bundles onto a view.
///
/// When a bundle is dropped:
/// 1. It is copied to a stable temp directory.
/// 2. The manifest is read to extract the game MD5.
/// 3. The matching `PVGame` is found in Realm.
/// 4. `SaveExporter.importSaves(from:for:)` restores the save files.
/// 5. The `onResult` callback is called on the main actor.
///
/// This modifier is intended for use on the Save States browser header/view
/// to allow bulk save-state imports without going through the file picker.
public struct SaveBundleDropModifier: ViewModifier {
    @State private var isTargeted = false
    let onResult: @MainActor (SaveBundleDropResult) -> Void

    public init(onResult: @escaping @MainActor (SaveBundleDropResult) -> Void) {
        self.onResult = onResult
    }

    public func body(content: Content) -> some View {
        content
            .onDrop(of: saveBundleAcceptedTypes, isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: isTargeted ? 3 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
                    .allowsHitTesting(false)
            )
    }

    @discardableResult
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        var handled = false
        for provider in providers {
            // Prefer a concrete file URL so we get the real on-disk path.
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                    if let error {
                        ELOG("SaveBundleDropModifier: loadItem error: \(error)")
                        Task { @MainActor in self.onResult(.failure(error)) }
                        return
                    }
                    // loadItem for public.file-url can return URL, NSURL, or Data — use shared helper.
                    guard let url = NSItemProvider.fileURL(fromLoadedItem: item) else {
                        let typeDescription = item.map { String(describing: type(of: $0)) } ?? "nil"
                        ELOG("SaveBundleDropModifier: unsupported item type for public.file-url: \(typeDescription)")
                        Task { @MainActor in
                            self.onResult(.failure(SaveExportError.invalidBundle("Dropped item has unsupported type: \(typeDescription)")))
                        }
                        return
                    }
                    processDroppedZip(url)
                }
                handled = true
                break
            } else {
                // Fallback: provider vends raw data — let the OS write it to a temp file.
                // Prefer a concrete registered archive type (e.g. public.zip-archive) over the
                // abstract parent, because some providers won't respond to the parent identifier.
                let zipTypeID = provider.registeredTypeIdentifiers.first(where: { id in
                    UTType(id)?.conforms(to: .archive) == true
                })

                if let zipTypeID, provider.hasItemConformingToTypeIdentifier(zipTypeID) {
                    provider.loadFileRepresentation(forTypeIdentifier: zipTypeID) { url, error in
                        if let error {
                            ELOG("SaveBundleDropModifier: loadFileRepresentation (zip) error: \(error)")
                            Task { @MainActor in self.onResult(.failure(error)) }
                            return
                        }
                        guard let url else {
                            ELOG("SaveBundleDropModifier: loadFileRepresentation (zip) returned nil URL with no error")
                            Task { @MainActor in self.onResult(.failure(SaveExportError.invalidBundle("Zip provider returned no file URL."))) }
                            return
                        }
                        processDroppedZip(url)
                    }
                    handled = true
                    break
                } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                        if let error {
                            ELOG("SaveBundleDropModifier: loadFileRepresentation (data) error: \(error)")
                            Task { @MainActor in self.onResult(.failure(error)) }
                            return
                        }
                        guard let url else {
                            ELOG("SaveBundleDropModifier: loadFileRepresentation (data) returned nil URL with no error")
                            Task { @MainActor in self.onResult(.failure(SaveExportError.invalidBundle("Data provider returned no file URL."))) }
                            return
                        }
                        processDroppedZip(url)
                    }
                    handled = true
                    break
                }
            }
        }
        return handled
    }

    /// Copies the zip to a stable location and then runs the import pipeline.
    private func processDroppedZip(_ sourceURL: URL) {
        Task {
            do {
                let stableURL = try stableCopy(of: sourceURL)
                defer { try? FileManager.default.removeItem(at: stableURL.deletingLastPathComponent()) }

                let ext = stableURL.pathExtension.lowercased()
                guard ext == "zip" || ext == "pvsave" else {
                    WLOG("SaveBundleDropModifier: dropped file is not a save bundle: \(stableURL.lastPathComponent)")
                    await MainActor.run {
                        onResult(.failure(SaveExportError.invalidBundle("Dropped file is not a .pvsave or .zip save-export bundle.")))
                    }
                    return
                }

                let (liveGame, error) = await findGame(inBundle: stableURL)

                if let error {
                    await MainActor.run { onResult(.failure(error)) }
                    return
                }
                // Freeze the Realm-managed object on the main actor so it can be safely
                // read from this background Task without violating thread confinement.
                let game = await MainActor.run { liveGame?.freeze() }
                guard let game else {
                    await MainActor.run { onResult(.missingGame) }
                    return
                }

                try await SaveExporter.shared.importSaves(from: stableURL, for: game)
                let title = game.title  // frozen objects are immutable and thread-safe
                await MainActor.run { onResult(.success(gameTitle: title)) }
            } catch {
                ELOG("SaveBundleDropModifier: import failed: \(error)")
                await MainActor.run { onResult(.failure(error)) }
            }
        }
    }

    /// Copies the URL to a uniquely-named temp subdirectory so the file survives
    /// async processing after the completion handler returns.
    private func stableCopy(of sourceURL: URL) throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVSaveDropImports", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let unique = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: unique, withIntermediateDirectories: true)
        let dest = unique.appendingPathComponent(sourceURL.lastPathComponent)
        // Files/iCloud providers may vend security-scoped URLs — request access before copying.
        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }

    /// Peeks at `manifest.json` inside the zip to find the game MD5 (via `SaveExporter`),
    /// then looks up the matching `PVGame` in the local Realm database.
    ///
    /// Returns `(nil, nil)` when no matching game is found but the manifest is valid.
    /// Returns `(nil, error)` when the manifest cannot be read or parsed.
    private func findGame(inBundle zipURL: URL) async -> (PVGame?, Error?) {
        // Delegate zip-peeking to SaveExporter, which owns the ZipArchive dependency.
        let md5: String? = await Task(priority: .userInitiated) {
            SaveExporter.shared.gameMD5(inBundleAt: zipURL)
        }.value

        guard let md5 else {
            WLOG("SaveBundleDropModifier: could not read MD5 from bundle \(zipURL.lastPathComponent)")
            return (nil, SaveExportError.invalidBundle("Could not read bundle manifest."))
        }

        // Find the matching PVGame on the main thread (Realm is main-thread-only).
        let game: PVGame? = await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            let candidates = [md5, md5.uppercased(), md5.lowercased()]
            var seen = Set<String>()
            for key in candidates where seen.insert(key).inserted {
                if let g = realm.object(ofType: PVGame.self, forPrimaryKey: key) {
                    return g
                }
            }
            WLOG("SaveBundleDropModifier: no game found for manifest MD5 '\(md5)'")
            return nil
        }

        return (game, nil)
    }
}

// MARK: - View extensions

public extension View {
    /// Attaches a save-state drag source to this view.
    ///
    /// When the user initiates a drag, the save-state file for `saveStateID` is
    /// resolved from Realm and offered as a `public.file-url`.
    ///
    /// Guard: iOS/iPadOS/macCatalyst only — do not call on tvOS.
    func saveStateDragSource(saveStateID: String) -> some View {
        modifier(SaveStateDragModifier(saveStateID: saveStateID))
    }

    /// Attaches a save-bundle drop target to this view.
    ///
    /// Accepts `.zip` archives previously created by `SaveExporter.exportSaves(for:)`.
    /// The bundle's embedded manifest is read to identify the target game automatically.
    ///
    /// - Parameter onResult: Called on the main actor with the import result.
    ///
    /// Guard: iOS/iPadOS/macCatalyst only — do not call on tvOS.
    func saveBundleDropTarget(onResult: @escaping @MainActor (SaveBundleDropResult) -> Void) -> some View {
        modifier(SaveBundleDropModifier(onResult: onResult))
    }
}
#endif // os(iOS)

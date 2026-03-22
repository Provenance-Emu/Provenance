//
//  ROMDropDelegate.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-21.
//  Copyright 2026 Provenance Emu. All rights reserved.
//
//  Implements native drag & drop ROM import (issues #2136 / #2659; PR #3406).
//  iOS/iPadOS/macCatalyst only — onDrop is unavailable on tvOS, watchOS, and macOS.
//

#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import PVLogging
import PVUIBase

// MARK: - Accepted drop types

/// UTTypes accepted by the ROM drop target.
///
/// - `.fileURL`        — direct file-URL drops from the Files app and other sources
/// - `.archive`        — `.zip` archives (ROM zips, save-export bundles, etc.)
/// - `.data`           — fallback for providers that only advertise generic binary data
///
/// Zip archives are explicitly included because many ROM sets are distributed as `.zip`
/// files and because `SaveExporter` export bundles are zips that can be re-imported via
/// the save-states browser drop target (`SaveBundleDropModifier`).
private let romAcceptedTypes: [UTType] = [
    .fileURL,
    .archive,
    .data,
]

// MARK: - View modifier

/// Applies a ROM drop target to any SwiftUI view.
/// Dropped files are handed off to `PVGameLibraryUpdatesController.handlePickedDocuments(_:)`,
/// which copies them to the Imports directory and enqueues them in the importer pipeline.
public struct ROMDropTargetModifier: ViewModifier {
    /// Feedback state so the view can highlight while a compatible item is hovering over it.
    @State private var isTargeted = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .onDrop(of: romAcceptedTypes, isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: isTargeted ? 3 : 0)
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
            // Prefer file URL representation so we get the real on-disk path.
            // Use `loadItem` for .fileURL — it returns the NSURL value directly,
            // unlike `loadFileRepresentation` which treats `public.file-url` as raw data.
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                    if let error {
                        ELOG("ROMDropDelegate: loadItem error: \(error)")
                        return
                    }
                    guard let url = item as? URL else { return }
                    // Copy to a stable location so the async import pipeline finds the file
                    // even if the source URL becomes inaccessible after this handler returns.
                    do {
                        let stableURL = try Self.stableCopy(of: url)
                        enqueueURL(stableURL)
                    } catch {
                        ELOG("ROMDropDelegate: failed to copy drop to stable location: \(error)")
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.archive.identifier) {
                // Zip / archive: use loadFileRepresentation so the OS writes it to a temp URL.
                provider.loadFileRepresentation(forTypeIdentifier: UTType.archive.identifier) { url, error in
                    if let error {
                        ELOG("ROMDropDelegate: loadFileRepresentation (archive) error: \(error)")
                        return
                    }
                    guard let url else { return }
                    do {
                        let stableURL = try Self.stableCopy(of: url)
                        enqueueURL(stableURL)
                    } catch {
                        ELOG("ROMDropDelegate: failed to copy drop (archive) to stable location: \(error)")
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                // Fallback: provider exposes generic data — load it so the OS copies it
                // to a temporary location and we receive a URL.
                provider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                    if let error {
                        ELOG("ROMDropDelegate: loadFileRepresentation (data) error: \(error)")
                        return
                    }
                    guard let url else { return }
                    do {
                        let stableURL = try Self.stableCopy(of: url)
                        enqueueURL(stableURL)
                    } catch {
                        ELOG("ROMDropDelegate: failed to copy drop (data) to stable location: \(error)")
                    }
                }
                handled = true
            }
        }

        return handled
    }

    /// Copies a dropped URL into an app-owned temporary directory so it survives past
    /// the completion handler. A UUID-named subdirectory provides uniqueness when multiple
    /// files share the same name (e.g. two ROMs named "game.sfc" dropped simultaneously),
    /// while preserving the original filename for the importer pipeline.
    private static func stableCopy(of sourceURL: URL) throws -> URL {
        let baseImportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVDropImports", isDirectory: true)
        try FileManager.default.createDirectory(at: baseImportDir, withIntermediateDirectories: true)
        let uniqueDir = baseImportDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: uniqueDir, withIntermediateDirectories: true)
        let dest = uniqueDir.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }

    /// Forwards a dropped URL to the library update pipeline on the main actor.
    private func enqueueURL(_ url: URL) {
        ILOG("ROMDropDelegate: Received drop URL: \(url.lastPathComponent)")
        Task { @MainActor in
            guard let updatesController = AppState.shared.libraryUpdatesController else {
                ELOG("ROMDropDelegate: libraryUpdatesController is nil, cannot enqueue \(url.lastPathComponent)")
                return
            }
            updatesController.handlePickedDocuments([url])
        }
    }
}

// MARK: - View extension

public extension View {
    /// Attaches the ROM drag & drop import target to this view.
    /// Dropped ROMs/zips are enqueued into `PVGameLibraryUpdatesController` and
    /// processed by the existing `PVGameImporter` pipeline.
    ///
    /// Guard: iOS/iPadOS/macCatalyst only — do not call on tvOS, watchOS, or macOS.
    func romDropTarget() -> some View {
        modifier(ROMDropTargetModifier())
    }
}
#endif // os(iOS)

//
//  PatchEntry.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Represents a ROM patch file associated with a base game ROM.
///
/// `PatchEntry` is the lightweight, persistence-agnostic value type.
/// PVLibrary wraps this in a Realm object for library storage.
public struct PatchEntry: Sendable, Codable, Identifiable, Equatable {
    /// Stable unique identifier for this patch entry.
    public var id: UUID
    /// Absolute path to the patch file on disk.
    public var patchFileURL: URL
    /// Detected (or user-confirmed) format of the patch file.
    public var format: PatchFormat
    /// Identifier of the base game in the library (e.g. Realm object ID or MD5).
    public var baseGameIdentifier: String?
    /// SHA-256 hash of the patch file itself (for cache keying).
    public var patchFileSHA256: String?
    /// User-visible metadata about the patch.
    public var metadata: PatchMetadata
    /// Date the patch was imported into the library.
    public var importDate: Date
    /// Whether the patch has been applied and cached at least once.
    public var hasBeenApplied: Bool

    public init(
        id: UUID = UUID(),
        patchFileURL: URL,
        format: PatchFormat,
        baseGameIdentifier: String? = nil,
        patchFileSHA256: String? = nil,
        metadata: PatchMetadata = PatchMetadata(),
        importDate: Date = Date(),
        hasBeenApplied: Bool = false
    ) {
        self.id = id
        self.patchFileURL = patchFileURL
        self.format = format
        self.baseGameIdentifier = baseGameIdentifier
        self.patchFileSHA256 = patchFileSHA256
        self.metadata = metadata
        self.importDate = importDate
        self.hasBeenApplied = hasBeenApplied
    }

    /// Display title: uses metadata title or falls back to patch filename.
    public var displayTitle: String {
        metadata.title ?? patchFileURL.deletingPathExtension().lastPathComponent
    }
}

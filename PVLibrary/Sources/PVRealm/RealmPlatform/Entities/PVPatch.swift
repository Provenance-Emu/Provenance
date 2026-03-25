//
//  PVPatch.swift
//  Provenance
//
//  Created by Provenance Agent on 3/24/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift
import PVLogging
import PVPrimitives
import PVPatching

/// A Realm-persisted record representing a ROM patch file linked (optionally) to a game.
@objcMembers
public final class PVPatch: RealmSwift.Object, Identifiable, Filed, LocalFileProvider {

    // MARK: - Primary Key

    /// Primary key for this patch record.
    /// Derived from `file.partialPath` (relative path) when available — idempotent across re-imports.
    /// Falls back to the absolute URL path when `partialPath` is empty, and to a random UUID
    /// only if neither is resolvable (non-idempotent; logged as a warning at import time).
    @Persisted(primaryKey: true) public var id: String = ""

    // MARK: - File & Game

    /// The on-disk patch file.
    @Persisted public var file: PVFile?

    /// The ROM this patch targets.  May be `nil` if the patch was imported before its ROM.
    @Persisted public var game: PVGame?

    // MARK: - Metadata

    /// When the patch was imported.
    @Persisted public var date: Date = Date()

    /// Raw string value of `PatchFormat` (e.g. `"ips"`, `"bps"`).
    @Persisted public var formatRawValue: String = ""

    /// User-visible name derived from metadata or the filename.
    @Persisted public var title: String?

    /// Patch author (from embedded metadata, if available).
    @Persisted public var author: String?

    /// Patch version string (from embedded metadata, if available).
    @Persisted public var version: String?

    /// Long-form description of the patch's changes.
    @Persisted public var patchDescription: String?

    // MARK: - State

    /// Whether the patch should be applied on the next launch.
    @Persisted public var isEnabled: Bool = false

    // MARK: - Origin

    /// The URL string this patch was originally fetched from (e.g. a ROM-hack database).
    @Persisted public var sourceURLString: String?

    // MARK: - Computed

    /// The strongly-typed patch format, derived from `formatRawValue`.
    public var format: PatchFormat? {
        PatchFormat(rawValue: formatRawValue)
    }

    // MARK: - Initialiser

    public convenience init(
        file: PVFile,
        game: PVGame? = nil,
        date: Date = Date(),
        format: PatchFormat,
        title: String? = nil,
        author: String? = nil,
        version: String? = nil,
        patchDescription: String? = nil,
        isEnabled: Bool = false,
        sourceURLString: String? = nil
    ) {
        self.init()
        // Derive a stable primary key from the file's relative path so that
        // re-importing the same patch updates the record rather than creating a duplicate.
        // A non-empty partialPath is ideal for idempotent imports; otherwise, we fall back to
        // the file's absolute URL path (idempotent per stable destination path), and only use
        // a random UUID if no path information is available.
        if file.partialPath.isEmpty {
            if let absolutePath = file.url?.path, !absolutePath.isEmpty {
                WLOG("PVFile.partialPath is empty — using absolute URL path for patch id; imports remain idempotent as long as the destination path stays stable")
            } else {
                WLOG("PVFile.partialPath and file URL path are unavailable — patch import may not be idempotent; falling back to a random UUID key")
            }
        }
        // Use relative path for deterministic, collision-resistant key.
        // Fall back to URL path (absolute but stable per destination) if partial path is unavailable.
        let stableKey = !file.partialPath.isEmpty
            ? file.partialPath
            : file.url?.path ?? UUID().uuidString
        self.id = stableKey
        self.file = file
        self.game = game
        self.date = date
        self.formatRawValue = format.rawValue
        self.title = title
        self.author = author
        self.version = version
        self.patchDescription = patchDescription
        self.isEnabled = isEnabled
        self.sourceURLString = sourceURLString
    }
}

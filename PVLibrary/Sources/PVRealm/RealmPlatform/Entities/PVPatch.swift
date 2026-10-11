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

/// How a patch was associated with a base game.
public enum PVPatchMatchState: String, PersistableEnum, Sendable {
    /// Imported, waiting for a base ROM or user choice.
    case pending
    /// Auto-matched with high confidence.
    case matched
    /// Explicitly linked by the user.
    case manual
}

/// A Realm-persisted record representing a ROM patch file linked (optionally) to a game.
@objcMembers
public final class PVPatch: RealmSwift.Object, Identifiable, Filed, LocalFileProvider {

    // MARK: - Primary Key

    /// Primary key for this patch record.
    /// Derived from `file.partialPath` (relative path) when available — idempotent across re-imports.
    @Persisted(primaryKey: true) public var id: String = ""

    // MARK: - File & Game

    /// The on-disk patch file.
    @Persisted public var file: PVFile?

    /// The ROM this patch targets. May be `nil` if the patch was imported before its ROM.
    @Persisted public var game: PVGame?

    /// Stable MD5 of the base game (survives temporary unlink / re-import).
    @Persisted(indexed: true) public var baseGameMD5: String?

    /// Managed variant game that launches the patched ROM with isolated saves/identity.
    @Persisted public var variantGame: PVGame?

    /// MD5 of the patched ROM artifact (uppercase), once applied.
    @Persisted public var variantGameMD5: String?

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

    /// Expected source ROM CRC32 embedded in the patch (BPS/UPS), if any.
    @Persisted public var sourceCRC32: Int = 0

    /// Whether `sourceCRC32` is meaningful (0 is a valid CRC).
    @Persisted public var hasSourceCRC32: Bool = false

    /// SHA-256 of the patch file.
    @Persisted public var patchSHA256: String?

    /// SHA-256 of the source ROM last used to build the cache artifact.
    @Persisted public var sourceSHA256: String?

    /// Unique human-readable stem for cache / save directories.
    @Persisted public var outputStem: String?

    /// Auto-match score (0...1+) from the last ranking pass.
    @Persisted public var matchScore: Double = 0

    /// Auto-match confidence raw value (`none`/`low`/`medium`/`high`/`exact`).
    @Persisted public var matchConfidenceRaw: String = PatchMatchConfidence.none.rawValue

    /// Pending / matched / manual.
    @Persisted public var matchState: PVPatchMatchState = .pending

    // MARK: - State

    /// Whether this patch is the default launch choice for its base game.
    @Persisted public var isDefaultLaunch: Bool = false

    /// Whether a separate library tile should be shown for the variant.
    @Persisted public var showAsLibraryTile: Bool = false

    /// Whether the patch should be applied on the next launch.
    /// Kept for compatibility; prefer `isDefaultLaunch`.
    @Persisted public var isEnabled: Bool = false

    // MARK: - Origin

    /// The URL string this patch was originally fetched from (e.g. a ROM-hack database).
    @Persisted public var sourceURLString: String?

    // MARK: - Computed

    public var format: PatchFormat? {
        PatchFormat(rawValue: formatRawValue)
    }

    public var matchConfidence: PatchMatchConfidence {
        get { PatchMatchConfidence(rawValue: matchConfidenceRaw) ?? .none }
        set { matchConfidenceRaw = newValue.rawValue }
    }

    public var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return file?.fileName.deletingPathExtension ?? "Patch"
    }

    public var sourceCRC32Value: UInt32? {
        hasSourceCRC32 ? UInt32(bitPattern: Int32(truncatingIfNeeded: sourceCRC32)) : nil
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
        sourceURLString: String? = nil,
        matchState: PVPatchMatchState = .pending
    ) {
        self.init()
        if file.partialPath.isEmpty {
            if let absolutePath = file.url?.path, !absolutePath.isEmpty {
                WLOG("PVFile.partialPath is empty — using absolute URL path for patch id")
            } else {
                WLOG("PVFile.partialPath and file URL path unavailable — falling back to random UUID key")
            }
        }
        let stableKey = !file.partialPath.isEmpty
            ? file.partialPath
            : file.url?.path ?? UUID().uuidString
        self.id = stableKey
        self.file = file
        self.game = game
        self.baseGameMD5 = game?.md5Hash
        self.date = date
        self.formatRawValue = format.rawValue
        self.title = title
        self.author = author
        self.version = version
        self.patchDescription = patchDescription
        self.isEnabled = isEnabled
        self.isDefaultLaunch = isEnabled
        self.sourceURLString = sourceURLString
        self.matchState = game == nil ? matchState : (matchState == .pending ? .manual : matchState)
        self.outputStem = file.fileName.deletingPathExtension
    }
}

private extension String {
    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }
}

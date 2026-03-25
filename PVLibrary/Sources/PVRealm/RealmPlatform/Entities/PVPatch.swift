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

/// Supported ROM patch file formats.
public enum PatchFormat: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case ips      = "ips"
    case ips32    = "ips32"
    case bps      = "bps"
    case ups      = "ups"
    case xdelta   = "xdelta"
    case delta    = "delta"
    case xdelta3  = "xdelta3"
    case vcdiff   = "vcdiff"
    case ppf      = "ppf"
    case aps      = "aps"
    case rup      = "rup"
    case nsp      = "nsp"

    /// All file extensions that are recognised as patch files.
    public static let allExtensions: Set<String> = Set(PatchFormat.allCases.map { $0.rawValue })

    /// Initialise from a file URL's path extension (case-insensitive).
    public init?(fileURL: URL) {
        self.init(rawValue: fileURL.pathExtension.lowercased())
    }
}

/// A Realm-persisted record representing a ROM patch file linked (optionally) to a game.
@objcMembers
public final class PVPatch: RealmSwift.Object, Identifiable, Filed, LocalFileProvider {

    // MARK: - Primary Key

    @Persisted(wrappedValue: UUID().uuidString, primaryKey: true) public var id: String

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

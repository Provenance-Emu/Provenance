//
//  SaveBundleManifestV2.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-27.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Enhanced save bundle manifest with per-save metadata and cross-emulator source info.
//  Schema v2 is backward-compatible with v1 (simple flat JSON).
//  Part of issue #3552 (save import/export protocols foundation).
//
//  Bundle layout:
//    manifest.json          — SaveBundleManifestV2, JSON-encoded
//    battery/               — battery save files (SRAM, RTC)
//      *.srm, *.sav, *.rtc
//    states/                — save state files + screenshots
//      *.svs
//      *.jpg
//

import Foundation

// MARK: - SaveBundleManifestParseError

public enum SaveBundleManifestParseError: LocalizedError {
    case invalidManifest(String)
    case unsupportedSchemaVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidManifest(let reason):
            return "The save bundle manifest is invalid: \(reason)"
        case .unsupportedSchemaVersion(let v):
            return "Unsupported save bundle schema version: \(v). Please update Provenance."
        }
    }
}

// MARK: - SaveBundleManifestV2

/// Schema v2 manifest embedded as `manifest.json` inside a `.pvsave` export bundle.
///
/// **Backward compatibility:** `parse(from:)` accepts both v1 (flat `[String: String]`)
/// and v2 manifests. When parsing v1, `batterySaves` and `saveStates` will be `nil`.
///
/// **CodingKeys note:** The `gameMD5` field is encoded as `"game"` to stay compatible
/// with v1 consumers that expect that key name.
public struct SaveBundleManifestV2: Codable, Sendable {

    public static let currentSchemaVersion = 2

    // MARK: - Top-level fields

    /// Manifest schema version: 1 = original flat format, 2 = this struct.
    public let schemaVersion: Int

    /// MD5 hash of the ROM file — used as Provenance's primary game identifier.
    public let gameMD5: String

    /// Human-readable game title (for display; not used for matching).
    public let gameTitle: String

    /// System identifier string (e.g. `"com.provenance.snes"`).
    public let systemIdentifier: String

    /// ISO-8601 string recording when this bundle was created.
    public let exportDate: String

    // MARK: - Source emulator (optional)

    /// Bundle ID of the app that produced this export, or `nil` for Provenance-native bundles.
    public let sourceEmulatorBundleID: String?

    /// Human-readable name of the source emulator (for display in import UI).
    public let sourceEmulatorName: String?

    // MARK: - Content index

    /// Battery/SRAM files in the `battery/` subdirectory. `nil` for v1-parsed manifests.
    public let batterySaves: [BatterySaveEntry]?

    /// Save-state files in the `states/` subdirectory. `nil` for v1-parsed manifests.
    public let saveStates: [SaveStateEntry]?

    // MARK: - Sub-types

    /// Metadata for a single battery/SRAM file.
    public struct BatterySaveEntry: Codable, Sendable {
        /// Filename within `battery/` (e.g. `SuperMario.srm`).
        public let filename: String
        /// File size in bytes, for integrity display.
        public let sizeBytes: Int?
        /// MD5 of the file, for integrity verification after copy.
        public let md5: String?

        public init(filename: String, sizeBytes: Int? = nil, md5: String? = nil) {
            self.filename = filename
            self.sizeBytes = sizeBytes
            self.md5 = md5
        }

        /// Returns `true` if `filename` is safe to use as a bare filename (no path separators,
        /// no leading dot, no traversal sequences).
        public var isSafeFilename: Bool { SaveBundleManifestV2.isSafeFilename(filename) }
    }

    /// Metadata for a single save-state file.
    public struct SaveStateEntry: Codable, Sendable {
        /// Filename within `states/` (e.g. `abc123.svs`).
        public let filename: String
        /// Corresponding screenshot filename within `states/`, if available.
        public let screenshotFilename: String?
        /// ISO-8601 date the save state was created.
        public let date: String?
        /// `true` if this was an auto-save rather than a user-initiated save.
        public let isAutosave: Bool?
        /// User-provided label or description.
        public let userDescription: String?
        /// Core bundle identifier that created this state (e.g. `"com.provenance.snes9x"`).
        public let coreIdentifier: String?

        public init(
            filename: String,
            screenshotFilename: String? = nil,
            date: String? = nil,
            isAutosave: Bool? = nil,
            userDescription: String? = nil,
            coreIdentifier: String? = nil
        ) {
            self.filename = filename
            self.screenshotFilename = screenshotFilename
            self.date = date
            self.isAutosave = isAutosave
            self.userDescription = userDescription
            self.coreIdentifier = coreIdentifier
        }

        /// Returns `true` if `filename` is safe to use as a bare filename.
        public var isSafeFilename: Bool { SaveBundleManifestV2.isSafeFilename(filename) }
    }

    /// Returns `true` if `name` is a safe bare filename: no path separators, no leading dot,
    /// no traversal sequences, and non-empty.
    public static func isSafeFilename(_ name: String) -> Bool {
        guard !name.isEmpty,
              !name.hasPrefix("."),    // rejects hidden files, ".", and ".."
              !name.contains("/"),     // rejects any path with a forward-slash component
              !name.contains("\\"),    // rejects Windows-style backslash paths
              !name.contains("\0")     // rejects null-byte injection
        else { return false }
        return true
    }

    // MARK: - CodingKeys

    // `gameMD5` is encoded as `"game"` so v1 readers that look for `manifest["game"]` still work.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case gameMD5 = "game"
        case gameTitle = "title"
        case systemIdentifier = "system"
        case exportDate
        case sourceEmulatorBundleID
        case sourceEmulatorName
        case batterySaves
        case saveStates
    }

    // MARK: - Init

    public init(
        gameMD5: String,
        gameTitle: String,
        systemIdentifier: String,
        exportDate: String,
        sourceEmulatorBundleID: String? = nil,
        sourceEmulatorName: String? = nil,
        batterySaves: [BatterySaveEntry]? = nil,
        saveStates: [SaveStateEntry]? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.gameMD5 = gameMD5
        self.gameTitle = gameTitle
        self.systemIdentifier = systemIdentifier
        self.exportDate = exportDate
        self.sourceEmulatorBundleID = sourceEmulatorBundleID
        self.sourceEmulatorName = sourceEmulatorName
        self.batterySaves = batterySaves
        self.saveStates = saveStates
    }

    // MARK: - Parsing

    /// Parse a manifest JSON blob, accepting both v1 and v2 formats.
    ///
    /// - Throws: `SaveBundleManifestParseError` if the data cannot be parsed or
    ///   contains an unsupported schema version.
    public static func parse(from data: Data) throws -> SaveBundleManifestV2 {
        let decoder = JSONDecoder()

        // Parse JSON once; route based on schemaVersion.
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SaveBundleManifestParseError.invalidManifest("Could not parse JSON.")
        }

        guard let version = rawSchemaVersion(from: raw) else {
            // No schemaVersion key — assume v1 (earliest bundles omitted the key).
            return try parseV1(from: raw)
        }

        switch version {
        case 1:
            return try parseV1(from: raw)
        case 2:
            do {
                let manifest = try decoder.decode(SaveBundleManifestV2.self, from: data)
                guard !manifest.gameMD5.isEmpty else {
                    throw SaveBundleManifestParseError.invalidManifest("Missing 'game' field.")
                }
                guard !manifest.systemIdentifier.isEmpty else {
                    throw SaveBundleManifestParseError.invalidManifest("Missing 'system' field.")
                }
                return manifest
            } catch let parseError as SaveBundleManifestParseError {
                throw parseError
            } catch {
                throw SaveBundleManifestParseError.invalidManifest(error.localizedDescription)
            }
        default:
            throw SaveBundleManifestParseError.unsupportedSchemaVersion(version)
        }
    }

    /// JSON-encode this manifest with pretty-printing and sorted keys for reproducible output.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    // MARK: - Private Helpers

    private static func rawSchemaVersion(from dict: [String: Any]) -> Int? {
        switch dict["schemaVersion"] {
        case let s as String:  return Int(s.trimmingCharacters(in: .whitespaces))
        case let i as Int:     return i
        case let n as NSNumber: return n.intValue
        default:               return nil
        }
    }

    private static func parseV1(from dict: [String: Any]) throws -> SaveBundleManifestV2 {
        guard let md5 = dict["game"] as? String, !md5.isEmpty else {
            throw SaveBundleManifestParseError.invalidManifest("Missing 'game' field.")
        }
        guard let title = dict["title"] as? String else {
            throw SaveBundleManifestParseError.invalidManifest("Missing 'title' field.")
        }
        guard let system = dict["system"] as? String, !system.isEmpty else {
            throw SaveBundleManifestParseError.invalidManifest("Missing 'system' field.")
        }
        let exportDate = dict["exportDate"] as? String ?? ""
        return SaveBundleManifestV2(
            gameMD5: md5,
            gameTitle: title,
            systemIdentifier: system,
            exportDate: exportDate
        )
    }
}

//
//  SkinSystemOverrideRegistry.swift
//  PVUIBase
//
//  Holds authoritative system mappings for installed skins, sourced from
//  catalog metadata sidecars (`<stem>.skinmeta`) written at install time and
//  from the cached remote catalog.  This lets the UI correctly group skins
//  whose `info.json` `gameTypeIdentifier` is misconfigured by the author
//  (for example a SEGA SG-1000 skin whose `info.json` accidentally declares
//  the GBA game type).
//

import Foundation
import PVLogging
import PVPrimitives
import PVSystems

// MARK: - Sidecar Codable Payload

/// On-disk representation of a `<stem>.skinmeta` JSON file.
///
/// Stored alongside the matching `.deltaskin` / `.manicskin` package under
/// `Documents/DeltaSkins/` so that catalog-derived metadata survives across
/// launches and is replicated by the CloudKit and iCloud Drive non-database
/// syncers (see `DeltaSkinSyncSupport.allowedExtensions`).
public struct SkinCatalogSidecar: Codable, Sendable, Equatable {
    /// Sidecar schema version; bump if the file layout changes.
    public let version: Int
    /// Catalog entry id used to install this skin.
    public let catalogEntryId: String?
    /// The skin's internal identifier from `info.json`, captured at install time.
    public let skinIdentifier: String?
    /// Display name from the catalog entry.
    public let name: String?
    /// Catalog system short codes (lowercase, e.g. `["sg1000"]`).
    public let systems: [String]
    /// Optional original game-type identifier URN from the catalog entry.
    public let gameTypeIdentifier: String?

    public init(
        version: Int = 1,
        catalogEntryId: String?,
        skinIdentifier: String?,
        name: String?,
        systems: [String],
        gameTypeIdentifier: String?
    ) {
        self.version = version
        self.catalogEntryId = catalogEntryId
        self.skinIdentifier = skinIdentifier
        self.name = name
        self.systems = systems
        self.gameTypeIdentifier = gameTypeIdentifier
    }
}

// MARK: - Registry Actor

/// Actor that resolves the authoritative set of catalog system codes for an
/// installed skin.  Lookups are layered:
///
/// 1. In-memory cache populated when the registry first sees a skin or when
///    callers explicitly register a sidecar.
/// 2. `<stem>.skinmeta` sidecar JSON next to the skin package on disk.
/// 3. The cached `SkinCatalogService` catalog, matched via the shared
///    ``matchingInstalledSkin(for:in:)`` helper so the same logic that powers
///    the catalog browser drives the override fallback.
///
/// Returning an empty set means "no override available" — callers should fall
/// back to the skin's declared `gameType` / `skinLayoutGroup`.
public actor SkinSystemOverrideRegistry {

    // MARK: - Singleton

    public static let shared = SkinSystemOverrideRegistry()

    /// Public initializer so tests and tooling can spin up a fresh registry
    /// without polluting the singleton's caches.
    public init() {}

    // MARK: - Caches

    /// skin.identifier -> override codes
    private var overridesByIdentifier: [String: Set<String>] = [:]
    /// skin.fileURL.standardizedFileURL.path -> override codes (used for skins
    /// whose internal identifier collides across files or is empty).
    private var overridesByPath: [String: Set<String>] = [:]
    /// Tracks skin identifiers that have already been queried but produced no
    /// override so we don't repeatedly hit disk / the catalog service.
    private var negativeIdentifierCache: Set<String> = []

    // MARK: - File Naming

    /// Sidecar files are stored next to the skin package and share its stem
    /// (e.g. `cool-skin.deltaskin` → `cool-skin.skinmeta`).
    public static let sidecarPathExtension = "skinmeta"

    /// Returns the sidecar file URL for a given skin package URL.
    public nonisolated static func sidecarURL(for skinFileURL: URL) -> URL {
        skinFileURL.deletingPathExtension().appendingPathExtension(sidecarPathExtension)
    }

    // MARK: - Public API

    /// Returns the catalog system codes that should be used for `skin`, if any.
    ///
    /// Codes are lowercased to align with `SystemIdentifier.skinCatalogSystemCode`
    /// and `SkinCatalogService.matchesAnySystemCode(in:filterCodes:)`.
    public func systemCodes(for skin: any DeltaSkinProtocol) async -> Set<String> {
        if let cached = overridesByIdentifier[skin.identifier], !cached.isEmpty {
            return cached
        }
        let pathKey = skin.fileURL.standardizedFileURL.path
        if let cached = overridesByPath[pathKey], !cached.isEmpty {
            return cached
        }
        if negativeIdentifierCache.contains(skin.identifier) {
            return []
        }

        if let sidecar = readSidecar(for: skin.fileURL) {
            let codes = Self.normalize(sidecar.systems)
            if !codes.isEmpty {
                overridesByIdentifier[skin.identifier] = codes
                overridesByPath[pathKey] = codes
                return codes
            }
        }

        if let codes = await catalogDerivedCodes(for: skin), !codes.isEmpty {
            overridesByIdentifier[skin.identifier] = codes
            overridesByPath[pathKey] = codes
            return codes
        }

        negativeIdentifierCache.insert(skin.identifier)
        return []
    }

    /// Batch lookup that maps each skin's identifier to its override codes
    /// (omitting skins with no override).  Avoids per-skin actor hops in tight
    /// filter loops like `DeltaSkinManager.skins(for:)`.
    public func overrideCodesByIdentifier(for skins: [any DeltaSkinProtocol]) async -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for skin in skins {
            let codes = await systemCodes(for: skin)
            if !codes.isEmpty {
                result[skin.identifier] = codes
            }
        }
        return result
    }

    /// Persist a sidecar for a freshly installed skin and warm the in-memory cache.
    public func writeSidecar(
        for skinFileURL: URL,
        entry: SkinCatalogEntry,
        skinIdentifier: String?
    ) async throws {
        let sidecar = SkinCatalogSidecar(
            catalogEntryId: entry.id,
            skinIdentifier: skinIdentifier,
            name: entry.name,
            systems: Array(Self.normalize(entry.systems)).sorted(),
            gameTypeIdentifier: entry.gameTypeIdentifier
        )
        try writeSidecar(sidecar, to: Self.sidecarURL(for: skinFileURL))

        let codes = Self.normalize(sidecar.systems)
        if let id = skinIdentifier, !codes.isEmpty {
            overridesByIdentifier[id] = codes
            negativeIdentifierCache.remove(id)
        }
        overridesByPath[skinFileURL.standardizedFileURL.path] = codes
    }

    /// Removes the sidecar (if present) and forgets any in-memory overrides
    /// associated with the skin.  Safe to call even when no sidecar exists.
    public func removeSidecar(for skinFileURL: URL, skinIdentifier: String?) async {
        let url = Self.sidecarURL(for: skinFileURL)
        try? FileManager.default.removeItem(at: url)
        overridesByPath.removeValue(forKey: skinFileURL.standardizedFileURL.path)
        if let id = skinIdentifier {
            overridesByIdentifier.removeValue(forKey: id)
            negativeIdentifierCache.remove(id)
        }
    }

    /// Drops every cached override.  Tests and tooling use this to start fresh.
    public func reset() async {
        overridesByIdentifier.removeAll()
        overridesByPath.removeAll()
        negativeIdentifierCache.removeAll()
    }

    // MARK: - Sidecar IO

    /// Reads and decodes a sidecar JSON file if it exists for the given skin.
    /// Errors are swallowed (and logged) since a malformed sidecar should not
    /// prevent the rest of the skin system from functioning.
    nonisolated public func readSidecar(for skinFileURL: URL) -> SkinCatalogSidecar? {
        let url = Self.sidecarURL(for: skinFileURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SkinCatalogSidecar.self, from: data)
        } catch {
            WLOG("SkinSystemOverrideRegistry: Failed to read sidecar at \(url.path): \(error)")
            return nil
        }
    }

    /// Writes the sidecar atomically, creating intermediate directories if needed.
    private func writeSidecar(_ sidecar: SkinCatalogSidecar, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sidecar)
        try data.write(to: url, options: [.atomic])
    }

    // MARK: - Catalog Fallback

    /// Looks up `skin` in the cached remote catalog (if any) and, when found,
    /// returns the catalog entry's normalized `systems` list.
    ///
    /// Uses the shared ``matchingInstalledSkin(for:in:)`` helper inverted: we
    /// iterate catalog entries until one matches the skin, so the matching
    /// rules stay aligned with the catalog browser.
    private func catalogDerivedCodes(for skin: any DeltaSkinProtocol) async -> Set<String>? {
        guard let catalog = await loadCachedCatalog() else { return nil }
        let entry = catalog.skins.first { entry in
            matchingInstalledSkin(for: entry, in: [skin]) != nil
        }
        guard let entry else { return nil }
        return Self.normalize(entry.systems)
    }

    /// Returns the cached catalog without forcing a network refresh.  The
    /// service falls back through memory → disk → bundled seed automatically.
    private func loadCachedCatalog() async -> SkinCatalog? {
        do {
            return try await SkinCatalogService.shared.fetchCatalog(forceRefresh: false)
        } catch {
            DLOG("SkinSystemOverrideRegistry: Catalog unavailable for override fallback: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private static func normalize(_ codes: [String]) -> Set<String> {
        Set(
            codes
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && !SkinCatalogService.isLegacySystemCode($0) }
        )
    }
}

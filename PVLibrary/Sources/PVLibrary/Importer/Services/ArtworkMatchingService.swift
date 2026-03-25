//
//  ArtworkMatchingService.swift
//  PVLibrary
//
//  Standalone, protocol-driven service for artwork matching.
//  Used by both ArtworkSearchQueue (import time) and BatchArtworkMatchingView (batch re-match).
//

import Foundation
import PVLogging
import PVLookup
import PVLookupTypes
import PVSystems

// MARK: - Protocol

/// Protocol for finding artwork metadata across multiple databases.
/// Implementations must be `Sendable` so they can be passed across actor boundaries.
public protocol ArtworkMatchingServiceProtocol: Sendable {
    /// Search for artwork using progressive fallback:
    /// 1. Exact title + system
    /// 2. Cleaned title + system
    /// 3. Filename-based search
    /// 4. MD5 ROM lookup → title → search
    ///
    /// - Parameters:
    ///   - title: Display title of the game (may include region/revision tags)
    ///   - filename: ROM filename without extension (used as a fallback search term)
    ///   - md5: MD5 hash of the ROM (used for ROM-lookup fallback)
    ///   - systemIdentifier: The console/system for this game (narrows results)
    ///   - artworkTypes: Which artwork types to return (e.g. `[.boxFront, .boxBack]`)
    /// - Returns: All matching `ArtworkMetadata` items, ranked best-first within each type.
    func findArtwork(
        title: String,
        filename: String?,
        md5: String?,
        systemIdentifier: SystemIdentifier?,
        artworkTypes: ArtworkType
    ) async throws -> [ArtworkMetadata]
}

// MARK: - Actor implementation

/// Default implementation that delegates to `PVLookup.shared`.
public actor ArtworkMatchingService: ArtworkMatchingServiceProtocol {

    public static let shared = ArtworkMatchingService()

    private let lookup: PVLookup

    public init(lookup: PVLookup = .shared) {
        self.lookup = lookup
    }

    public func findArtwork(
        title: String,
        filename: String?,
        md5: String?,
        systemIdentifier: SystemIdentifier?,
        artworkTypes: ArtworkType = .defaults
    ) async throws -> [ArtworkMetadata] {

        let cleanedTitle = title.artworkSearchCleaned()
        let cleanedFilename = filename?.artworkSearchCleaned() ?? ""
        let originalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Build an ordered list of (label, search term) pairs, deduplicating equal strings.
        var searchTerms: [(label: String, term: String)] = [
            ("original title", originalTitle),
            ("cleaned title", cleanedTitle),
            ("filename", cleanedFilename)
        ].filter { !$0.term.isEmpty }

        // If cleaned title is the same as original, skip it to avoid a redundant round-trip.
        if cleanedTitle.lowercased() == originalTitle.lowercased() {
            searchTerms.removeAll { $0.label == "cleaned title" }
        }

        var results: [ArtworkMetadata] = []

        // --- Pass 1: title/filename searches ---
        for (label, term) in searchTerms {
            if let systemID = systemIdentifier {
                if let found = try? await lookup.searchArtwork(
                    byGameName: term,
                    systemID: systemID,
                    artworkTypes: artworkTypes
                ), !found.isEmpty {
                    ILOG("ArtworkMatchingService: \(found.count) result(s) via \(label) + system \(systemID.rawValue)")
                    return found   // best match: term + system
                }
            }

            // Broader search without system filter
            if results.isEmpty,
               let found = try? await lookup.searchArtwork(
                    byGameName: term,
                    systemID: nil,
                    artworkTypes: artworkTypes
               ), !found.isEmpty {
                ILOG("ArtworkMatchingService: \(found.count) result(s) via \(label) (no system filter)")
                results = found   // keep as candidate; try next term with system first
            }
        }

        if !results.isEmpty {
            return results
        }

        // --- Pass 2: MD5 ROM lookup ---
        guard let md5 = md5, !md5.isEmpty else {
            return []
        }

        let md5Upper = md5.uppercased()
        if let romMeta = try? await lookup.searchROM(byMD5: md5Upper) {
            let romTitle = romMeta.gameTitle.artworkSearchCleaned()
            guard !romTitle.isEmpty else { return [] }

            if let systemID = systemIdentifier,
               let found = try? await lookup.searchArtwork(
                    byGameName: romTitle,
                    systemID: systemID,
                    artworkTypes: artworkTypes
               ), !found.isEmpty {
                ILOG("ArtworkMatchingService: \(found.count) result(s) via MD5 ROM title + system")
                return found
            }

            if let found = try? await lookup.searchArtwork(
                    byGameName: romTitle,
                    systemID: nil,
                    artworkTypes: artworkTypes
               ), !found.isEmpty {
                ILOG("ArtworkMatchingService: \(found.count) result(s) via MD5 ROM title (no system filter)")
                return found
            }
        }

        return []
    }
}

// MARK: - String helper

extension String {
    /// Strip region/revision tags from a game title so it matches database entries.
    /// Identical to the logic previously duplicated in `ArtworkSearchQueue` and
    /// `BatchArtworkMatchingView`.
    func artworkSearchCleaned() -> String {
        var cleaned = self

        // Remove bracketed annotations: [], (), {}
        for pattern in ["\\[.*?\\]", "\\(.*?\\)", "\\{.*?\\}"] {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // Remove isolated punctuation characters
        cleaned = cleaned.replacingOccurrences(
            of: "\\s[,:;!^%&*+/\\-]\\s",
            with: " ",
            options: .regularExpression
        )

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

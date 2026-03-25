//
//  ArtworkMatchingService.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/25/26.
//

import Foundation
import PVLookup
import PVLookupTypes
import PVPrimitives
import PVSystems
import PVLogging

/// Artwork source databases that can be searched.
public enum ArtworkSource: String, CaseIterable, Identifiable, Sendable {
    case openVGDB = "OpenVGDB"
    case theGamesDB = "TheGamesDB"
    case libretroDB = "LibretroDB"

    public var id: String { rawValue }

    public var displayName: String { rawValue }
}

/// Service layer for batch artwork lookup.
///
/// Wraps `PVLookup.shared.searchArtwork` with:
/// - Title normalization via `FuzzyGameMatcher.normalize`
/// - Per-source filtering based on the caller's enabled set
/// - First-3-word fallback when the full title yields no results
public enum ArtworkMatchingService {

    /// Find box-front artwork for a game, filtering to the requested sources.
    ///
    /// - Parameters:
    ///   - gameTitle: Raw ROM title; normalized internally via `FuzzyGameMatcher`.
    ///   - systemID: System identifier string for the game.
    ///   - enabledSources: Sources to include in results. Pass the full
    ///     `ArtworkSource.allCases` set (or leave default) to query all sources.
    /// - Returns: Filtered artwork results, or `nil` if nothing was found.
    public static func findArtwork(
        gameTitle: String,
        systemID: String,
        enabledSources: Set<ArtworkSource> = Set(ArtworkSource.allCases)
    ) async throws -> [ArtworkMetadata]? {
        let normalizedTitle = FuzzyGameMatcher.normalize(gameTitle)
        let systemIdentifier = SystemIdentifier(rawValue: systemID)

        DLOG("ArtworkMatchingService: searching '\(normalizedTitle)' (from '\(gameTitle)')")

        // Full normalized title
        if let results = try await PVLookup.shared.searchArtwork(
            byGameName: normalizedTitle,
            systemID: systemIdentifier,
            artworkTypes: .boxFront
        ), !results.isEmpty {
            let filtered = filter(results, sources: enabledSources)
            if !filtered.isEmpty {
                DLOG("ArtworkMatchingService: found \(filtered.count) results for '\(normalizedTitle)'")
                return filtered
            }
        }

        // Fallback: first 3 words of the normalized title
        let words = normalizedTitle
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if words.count > 3 {
            let shortTitle = words.prefix(3).joined(separator: " ")
            DLOG("ArtworkMatchingService: retrying with first 3 words '\(shortTitle)'")

            if let results = try await PVLookup.shared.searchArtwork(
                byGameName: shortTitle,
                systemID: systemIdentifier,
                artworkTypes: .boxFront
            ), !results.isEmpty {
                let filtered = filter(results, sources: enabledSources)
                if !filtered.isEmpty {
                    DLOG("ArtworkMatchingService: found \(filtered.count) results for '\(shortTitle)'")
                    return filtered
                }
            }
        }

        DLOG("ArtworkMatchingService: no artwork found for '\(gameTitle)'")
        return nil
    }

    // MARK: - Private

    private static func filter(
        _ results: [ArtworkMetadata],
        sources: Set<ArtworkSource>
    ) -> [ArtworkMetadata] {
        guard !sources.isEmpty else { return results }
        let sourceNames = Set(sources.map(\.rawValue))
        return results.filter { sourceNames.contains($0.source) }
    }
}

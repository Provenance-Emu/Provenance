//
//  CoreRecommendationEngine.swift
//  PVCoreLoader
//
//  Created by Claude on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVPrimitives
import PVLogging

// MARK: - CoreRecommendation

/// The output of ``CoreRecommendationEngine`` for a single candidate core.
public struct CoreRecommendation: Sendable {
    /// The core identifier this recommendation refers to.
    public let coreIdentifier: String

    /// Number of save states the user has for this core/game combination.
    public let saveCount: Int

    /// How well this core suits the game, compared with other available cores.
    public enum Rank: Sendable {
        /// Best option for this game — show a "Recommended" badge.
        case recommended
        /// Good option with no game-specific edge.
        case standard
        /// Works but there are better alternatives.
        case fallback
    }

    /// Ranking relative to other available cores.
    public let rank: Rank

    /// Ordered list of capabilities that make this core a good match for the game.
    /// Used to populate the capability chip row in the UI.
    public let highlightedCapabilities: [CoreCapability]

    /// Human-readable tip that explains *why* this core is recommended.
    /// `nil` if there is no specific recommendation reason.
    public let recommendationTip: String?

    /// Resolved capability metadata for this core, if available.
    public let metadata: CoreCapabilityMetadata?
}

// MARK: - CoreRecommendationEngine

/// Ranks available cores for a specific game, taking into account:
/// - Per-game / per-system feature requirements (from `CoreCapabilities.json`)
/// - Capability quality rank
/// - Number of existing save states (user should not lose progress)
///
/// Usage:
/// ```swift
/// let engine = CoreRecommendationEngine.shared
/// let recs = engine.recommendations(
///     forGame: game,
///     availableCoreIdentifiers: coreIDs,
///     saveCounts: savesPerCore
/// )
/// ```
/// `@unchecked Sendable`: `manifest` is written once in `init` via a static helper
/// and is never mutated after construction, so concurrent reads are safe.
public final class CoreRecommendationEngine: @unchecked Sendable {

    // MARK: Singleton

    public static let shared = CoreRecommendationEngine()

    // MARK: Private state

    private let manifest: CoreCapabilitiesManifest?

    // MARK: Init

    public init() {
        manifest = Self.loadManifest()
    }

    // MARK: - Public API

    /// Returns recommendations for the given cores, sorted best-first.
    ///
    /// - Parameters:
    ///   - gameTitle: Title of the game (for title-contains matching).
    ///   - systemIdentifier: System ID string (for system-level matching).
    ///   - md5: ROM MD5 hash (for exact-hash matching).
    ///   - serial: ROM serial / product code (for serial matching).
    ///   - availableCoreIdentifiers: Identifiers of cores that support the game.
    ///   - saveCounts: Map from core identifier → number of save states for this game.
    /// - Returns: Array of ``CoreRecommendation``, sorted best-first.
    public func recommendations(
        gameTitle: String,
        systemIdentifier: String?,
        md5: String? = nil,
        serial: String? = nil,
        availableCoreIdentifiers: [String],
        saveCounts: [String: Int] = [:]
    ) -> [CoreRecommendation] {

        guard !availableCoreIdentifiers.isEmpty else { return [] }

        // Gather matching game requirements
        let matchingRequirements = matchingGameRequirements(
            title: gameTitle,
            systemIdentifier: systemIdentifier,
            md5: md5,
            serial: serial
        )

        // Merge all preferred capabilities from requirements
        let allPreferredCapabilities: Set<CoreCapability> = matchingRequirements.reduce(into: []) {
            $0.formUnion($1.preferredCapabilities)
        }

        // Collect the best tip message (first non-nil tip)
        let tipMessage = matchingRequirements.compactMap { $0.tip }.first

        var recs: [CoreRecommendation] = availableCoreIdentifiers.map { coreID in
            let meta = manifest?.metadata(for: coreID)
            let saveCount = saveCounts[coreID] ?? 0
            let coreCapabilities = meta?.capabilities ?? []

            // Which of the preferred capabilities does this core support?
            let highlighted = allPreferredCapabilities
                .filter { coreCapabilities.contains($0) }
                .sorted { $0.rawValue < $1.rawValue }

            return CoreRecommendation(
                coreIdentifier: coreID,
                saveCount: saveCount,
                rank: .standard,           // assigned below
                highlightedCapabilities: highlighted,
                recommendationTip: highlighted.isEmpty ? nil : tipMessage,
                metadata: meta
            )
        }

        // Sort: saves first (never lose progress), then by feature match score, then qualityRank
        recs.sort { lhs, rhs in
            // 1. Existing saves — keep the user on their current core
            if lhs.saveCount != rhs.saveCount { return lhs.saveCount > rhs.saveCount }

            // 2. Feature match score — more highlighted capabilities = better
            if lhs.highlightedCapabilities.count != rhs.highlightedCapabilities.count {
                return lhs.highlightedCapabilities.count > rhs.highlightedCapabilities.count
            }

            // 3. Quality rank from manifest
            let lRank = lhs.metadata?.qualityRank ?? 0
            let rRank = rhs.metadata?.qualityRank ?? 0
            return lRank > rRank
        }

        // Assign rank labels
        if let best = recs.first {
            let isRecommended = !best.highlightedCapabilities.isEmpty
                || (best.metadata?.qualityRank ?? 0) > 0

            recs = recs.enumerated().map { idx, rec in
                let rank: CoreRecommendation.Rank
                if idx == 0 && isRecommended {
                    rank = .recommended
                } else if idx == recs.count - 1 && recs.count > 2 {
                    rank = .fallback
                } else {
                    rank = .standard
                }
                return CoreRecommendation(
                    coreIdentifier: rec.coreIdentifier,
                    saveCount: rec.saveCount,
                    rank: rank,
                    highlightedCapabilities: rec.highlightedCapabilities,
                    recommendationTip: idx == 0 ? rec.recommendationTip : nil,
                    metadata: rec.metadata
                )
            }

            // Suppress "recommended" badge when there's only one core
            if recs.count == 1 {
                let single = recs[0]
                recs = [CoreRecommendation(
                    coreIdentifier: single.coreIdentifier,
                    saveCount: single.saveCount,
                    rank: .standard,
                    highlightedCapabilities: single.highlightedCapabilities,
                    recommendationTip: single.recommendationTip,
                    metadata: single.metadata
                )]
            }
        }

        return recs
    }

    /// Convenience overload that accepts the PVPrimitives `Game` protocol.
    public func recommendations(
        forGame game: any GameProtocol,
        availableCoreIdentifiers: [String],
        saveCounts: [String: Int] = [:]
    ) -> [CoreRecommendation] {
        recommendations(
            gameTitle: game.title,
            systemIdentifier: game.systemIdentifier,
            md5: game.md5Hash,
            serial: game.romSerial,
            availableCoreIdentifiers: availableCoreIdentifiers,
            saveCounts: saveCounts
        )
    }

    // MARK: - Manifest access

    /// Returns the capability metadata for a specific core, or `nil` if not found.
    public func capabilityMetadata(for coreIdentifier: String) -> CoreCapabilityMetadata? {
        manifest?.metadata(for: coreIdentifier)
    }

    // MARK: - Private helpers

    private func matchingGameRequirements(
        title: String,
        systemIdentifier: String?,
        md5: String?,
        serial: String?
    ) -> [GameFeatureRequirement] {
        guard let requirements = manifest?.gameRequirements else { return [] }

        return requirements.filter { req in
            switch req.matchStrategy {
            case .md5:
                guard let md5 = md5 else { return false }
                return md5.caseInsensitiveCompare(req.matchValue) == .orderedSame
            case .serial:
                guard let serial = serial else { return false }
                return serial.caseInsensitiveCompare(req.matchValue) == .orderedSame
            case .titleContains:
                return title.localizedCaseInsensitiveContains(req.matchValue)
            case .systemIdentifier:
                guard let sysID = systemIdentifier else { return false }
                return sysID == req.matchValue
            }
        }
    }

    // MARK: - Manifest loading

    private static func loadManifest() -> CoreCapabilitiesManifest? {
        guard let url = Bundle.module.url(forResource: "CoreCapabilities", withExtension: "json") else {
            WLOG("CoreCapabilities.json not found in PVCoreLoader bundle")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(CoreCapabilitiesManifest.self, from: data)
            DLOG("Loaded CoreCapabilities.json: \(manifest.cores.count) cores, \(manifest.gameRequirements.count) game requirements")
            return manifest
        } catch {
            ELOG("Failed to decode CoreCapabilities.json: \(error)")
            return nil
        }
    }
}

// MARK: - GameProtocol

/// Minimal protocol used by ``CoreRecommendationEngine`` to consume game objects
/// without importing higher-level modules like PVLibrary.
public protocol GameProtocol: Sendable {
    var title: String { get }
    var systemIdentifier: String? { get }
    var md5Hash: String? { get }
    var romSerial: String? { get }
}

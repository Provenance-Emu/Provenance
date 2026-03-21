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
import PVPlists

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
/// `manifest` is a `let` constant set once in `init` and never mutated.
/// `CoreCapabilitiesManifest` is `Sendable`, so this type is fully `Sendable`.
public final class CoreRecommendationEngine: Sendable {

    // MARK: Singleton

    public static let shared = CoreRecommendationEngine()

    // MARK: Private state

    private let manifest: CoreCapabilitiesManifest?

    // MARK: Init

    public init(manifest: CoreCapabilitiesManifest? = nil) {
        if let manifest {
            self.manifest = manifest
        } else {
            self.manifest = Self.loadManifest()
        }
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

        // Rank requirements by match specificity: md5 > serial > titleContains > systemIdentifier.
        // Use the single most-specific requirement for capabilities so a broad rule cannot
        // override a narrower, game-specific rule (e.g. an explicit empty set for Pokémon Snap).
        let score: (GameFeatureRequirement) -> Int = { req in
            switch req.matchStrategy {
            case .md5:              return 8
            case .serial:           return 4
            case .titleContains:    return 2
            case .systemIdentifier: return 1
            }
        }

        let bestRequirement = matchingRequirements.max { score($0) < score($1) }
        let allPreferredCapabilities: Set<CoreCapability> = bestRequirement?.preferredCapabilities ?? []

        // Collect the best tip message from the most-specific match that has one.
        let tipMessage = matchingRequirements
            .sorted { score($0) > score($1) }
            .compactMap { $0.tip }
            .first

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

        // Precompute input-order index map once for O(1) tie-breaker lookups in the sort.
        let inputOrder = Dictionary(availableCoreIdentifiers.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

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
            if lRank != rRank { return lRank > rRank }

            // 4. Stable tie-breaker: preserve the original input order for a consistent UI
            let lhsIdx = inputOrder[lhs.coreIdentifier] ?? Int.max
            let rhsIdx = inputOrder[rhs.coreIdentifier] ?? Int.max
            return lhsIdx < rhsIdx
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

    /// Builds the capabilities manifest using a three-layer strategy:
    ///
    /// 1. **Auto-derived** — capabilities deduced from each core's `EmulatorCoreInfoPlist`
    ///    (e.g. `cheats` from `supportedCheatTypes`, `requiresJIT` from `jitRequirementRawValue`,
    ///    explicit `PVCapabilities` array if present).  This layer is always up-to-date because
    ///    `CoreLoader` loads it directly from the installed `Core.plist` files at runtime.
    ///
    /// 2. **Enrichment** — `CoreCapabilities.json` (bundled in PVCoreLoader) provides editorial
    ///    data that cannot be auto-derived: `summary`, `qualityRank`, `notes`, and capability
    ///    flags that require human judgment (e.g. `highAccuracy`, `mouseSupport`).  Enrichment
    ///    data is merged on top of the auto-derived layer; auto-derived capabilities are never
    ///    removed by the enrichment layer.
    ///
    /// 3. **Fallback** — if `CoreLoader` produces no plists (e.g. in unit tests that don't have
    ///    a full app bundle), the manifest falls back to `CoreCapabilities.json` alone so that
    ///    tests and the recommendation engine continue to work.
    ///
    /// **Adding a new core:** add a `Core.plist` with `PVSupportedCheatTypes` / `PVCapabilities`
    /// and the engine will pick it up automatically.  Add a corresponding entry to
    /// `CoreCapabilities.json` only if you want to supply a `summary`, `qualityRank`, or
    /// capabilities that can't be expressed in the plist.
    private static func loadManifest() -> CoreCapabilitiesManifest? {
        // --- Layer 1: auto-derive from Core.plist files loaded at runtime ---
        let corePlists = CoreLoader.getCorePlists()
        var allPlists: [EmulatorCoreInfoPlist] = corePlists
        // Flatten sub-cores (e.g. RetroArch libretro bundles)
        for plist in corePlists {
            if let subs = plist.subCores {
                allPlists.append(contentsOf: subs)
            }
        }

        var derivedByID: [String: CoreCapabilityMetadata] = [:]
        for plist in allPlists {
            var caps = Set<CoreCapability>()

            // Derive from supportedCheatTypes
            if !plist.supportedCheatTypes.isEmpty {
                caps.insert(.cheats)
            }

            // Derive from JIT requirement
            if plist.jitRequirementRawValue != nil {
                caps.insert(.requiresJIT)
            }

            // Explicit PVCapabilities from Core.plist (authoritative per-core source)
            for rawValue in plist.capabilities {
                if let cap = CoreCapability(rawValue: rawValue) {
                    caps.insert(cap)
                } else {
                    WLOG("CoreRecommendationEngine: Unknown PVCapabilities value '\(rawValue)' in Core.plist for \(plist.identifier)")
                }
            }

            derivedByID[plist.identifier] = CoreCapabilityMetadata(
                coreIdentifier: plist.identifier,
                summary: nil,
                capabilities: caps,
                notes: [],
                qualityRank: 0
            )
        }

        // --- Layer 2: enrichment from CoreCapabilities.json ---
        let enrichmentManifest = loadEnrichmentManifest()

        // Merge: plist-derived as base, JSON as enrichment
        var mergedCores: [CoreCapabilityMetadata]
        if !derivedByID.isEmpty {
            // Start from all identifiers seen across both layers
            var allIDs = Set(derivedByID.keys)
            if let enrichment = enrichmentManifest {
                enrichment.cores.forEach { allIDs.insert($0.coreIdentifier) }
            }

            mergedCores = allIDs.sorted().compactMap { id in
                let derived = derivedByID[id]
                let enriched = enrichmentManifest?.metadata(for: id)

                // If only enrichment knows this core (not yet installed / not in plists),
                // use it as-is so editorial data is still surfaced.
                guard let derived else { return enriched }

                // Merge capabilities: union of auto-derived + editorial
                let mergedCaps = derived.capabilities.union(enriched?.capabilities ?? [])

                return CoreCapabilityMetadata(
                    coreIdentifier: id,
                    summary: enriched?.summary ?? derived.summary,
                    capabilities: mergedCaps,
                    notes: enriched?.notes ?? derived.notes,
                    qualityRank: enriched?.qualityRank ?? derived.qualityRank
                )
            }
            ILOG("CoreRecommendationEngine: built manifest from \(derivedByID.count) installed plists + enrichment for \(allIDs.count) total cores")
        } else {
            // --- Layer 3: fallback — no plists available (tests / early launch) ---
            WLOG("CoreRecommendationEngine: no Core.plists available — using CoreCapabilities.json as sole source")
            guard let enrichment = enrichmentManifest else {
                ELOG("CoreRecommendationEngine: CoreCapabilities.json also unavailable — no capability data")
                return nil
            }
            return enrichment
        }

        let gameRequirements = enrichmentManifest?.gameRequirements ?? []
        return CoreCapabilitiesManifest(version: 2, cores: mergedCores, gameRequirements: gameRequirements)
    }

    /// Loads `CoreCapabilities.json` as the enrichment/editorial data layer.
    private static func loadEnrichmentManifest() -> CoreCapabilitiesManifest? {
        guard let url = Bundle.module.url(forResource: "CoreCapabilities", withExtension: "json") else {
            WLOG("CoreCapabilities.json not found in PVCoreLoader bundle")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(CoreCapabilitiesManifest.self, from: data)
            DLOG("CoreRecommendationEngine: loaded CoreCapabilities.json (\(manifest.cores.count) enrichment entries, \(manifest.gameRequirements.count) game requirements)")
            return manifest
        } catch {
            ELOG("CoreRecommendationEngine: failed to decode CoreCapabilities.json: \(error)")
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

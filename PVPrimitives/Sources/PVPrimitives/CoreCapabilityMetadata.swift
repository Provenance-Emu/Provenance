//
//  CoreCapabilityMetadata.swift
//  PVPrimitives
//
//  Created by Claude on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

// MARK: - CoreCapabilityMetadata

/// Capability profile for a single emulator core.
///
/// These structs are loaded from `CoreCapabilities.json` (bundled in PVCoreLoader)
/// and used by ``CoreRecommendationEngine`` to rank cores for a given game.
public struct CoreCapabilityMetadata: Codable, Sendable, Hashable {

    /// The core's bundle identifier (matches `PVCore.identifier`).
    public let coreIdentifier: String

    /// Human-readable description of the core's strengths and trade-offs,
    /// shown below the core name in the selection sheet.
    public let summary: String?

    /// Set of capabilities this core supports.
    public let capabilities: Set<CoreCapability>

    /// Ordered list of notes shown as bullet points in the selection UI.
    /// Use this for nuances that don't map to a capability flag (e.g. "Beta quality",
    /// "Requires iOS 18+ for best performance").
    public let notes: [String]

    /// Overall quality tier for sorting when no game-specific recommendation applies.
    /// Higher value = shown earlier in the list.
    public let qualityRank: Int

    public init(
        coreIdentifier: String,
        summary: String? = nil,
        capabilities: Set<CoreCapability> = [],
        notes: [String] = [],
        qualityRank: Int = 0
    ) {
        self.coreIdentifier = coreIdentifier
        self.summary = summary
        self.capabilities = capabilities
        self.notes = notes
        self.qualityRank = qualityRank
    }
}

// MARK: - GameFeatureRequirement

/// Describes a feature a particular game needs for the best experience.
///
/// Instances are loaded from ``CoreCapabilitiesManifest/gameRequirements`` and
/// matched against the current game's MD5 hash, serial, or title keyword.
public struct GameFeatureRequirement: Codable, Sendable {

    /// Match strategy used to identify the game.
    public enum MatchStrategy: String, Codable, Sendable {
        /// Match against the ROM's MD5 hash.
        case md5
        /// Match against the ROM's serial number (e.g. NDS cart serial).
        case serial
        /// Case-insensitive substring match against the game title.
        case titleContains
        /// Match any game on this system identifier.
        case systemIdentifier
    }

    /// The match strategy to apply.
    public let matchStrategy: MatchStrategy

    /// The value to match against (hash hex string, serial, title substring, or system ID).
    public let matchValue: String

    /// Capabilities that meaningfully improve this game's experience.
    /// Used to re-rank cores in the selection UI.
    public let preferredCapabilities: Set<CoreCapability>

    /// Human-readable explanation shown as a "recommendation tip" in the UI.
    /// Example: "This game uses the SNES Mouse — choose a core with mouse support."
    public let tip: String?

    public init(
        matchStrategy: MatchStrategy,
        matchValue: String,
        preferredCapabilities: Set<CoreCapability>,
        tip: String? = nil
    ) {
        self.matchStrategy = matchStrategy
        self.matchValue = matchValue
        self.preferredCapabilities = preferredCapabilities
        self.tip = tip
    }
}

// MARK: - CoreCapabilitiesManifest

/// Top-level container decoded from `CoreCapabilities.json`.
public struct CoreCapabilitiesManifest: Codable, Sendable {

    /// Schema version — increment when adding new capability keys or changing structure.
    public let version: Int

    /// Capability profiles keyed by core identifier.
    public let cores: [CoreCapabilityMetadata]

    /// Per-game (or per-system) feature requirements used for smart recommendations.
    public let gameRequirements: [GameFeatureRequirement]

    /// O(1) lookup dictionary built from `cores` on init.
    private let coresByIdentifier: [String: CoreCapabilityMetadata]

    private enum CodingKeys: String, CodingKey {
        case version, cores, gameRequirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        cores = try container.decode([CoreCapabilityMetadata].self, forKey: .cores)
        gameRequirements = try container.decode([GameFeatureRequirement].self, forKey: .gameRequirements)
        coresByIdentifier = Dictionary(cores.map { ($0.coreIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public init(version: Int, cores: [CoreCapabilityMetadata], gameRequirements: [GameFeatureRequirement]) {
        self.version = version
        self.cores = cores
        self.gameRequirements = gameRequirements
        self.coresByIdentifier = Dictionary(cores.map { ($0.coreIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Looks up the capability metadata for the given core identifier in O(1).
    public func metadata(for coreIdentifier: String) -> CoreCapabilityMetadata? {
        coresByIdentifier[coreIdentifier]
    }
}

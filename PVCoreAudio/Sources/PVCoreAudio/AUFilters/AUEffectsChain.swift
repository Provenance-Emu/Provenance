//
//  AUEffectsChain.swift
//  PVCoreAudio
//
//  Created by Claude on 3/25/26.
//  Part of #3489 — AU filter support
//

import Foundation
import Defaults

/// An ordered chain of audio effect nodes applied to the emulator audio output.
public struct AUEffectsChain: Codable, Sendable, Equatable {
    /// Ordered list of effects nodes. Applied source → first → … → last → output.
    public var nodes: [AUEffectNode]

    public static let empty = AUEffectsChain(nodes: [])

    public init(nodes: [AUEffectNode] = []) {
        self.nodes = nodes
    }

    /// Returns true when the chain has at least one enabled node.
    /// The master on/off toggle is `Defaults[.auFiltersEnabled]` — not stored in the chain.
    public var hasActiveEffects: Bool {
        nodes.contains { $0.isEnabled }
    }

    /// Returns only the nodes that are currently enabled.
    public var activeNodes: [AUEffectNode] {
        nodes.filter(\.isEnabled)
    }
}

extension AUEffectsChain: Defaults.Serializable {}

// MARK: - AUEffectsPreset

/// A named snapshot of an effects chain that can be saved and recalled.
public struct AUEffectsPreset: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var chain: AUEffectsChain
    public var createdAt: Date

    public init(name: String, chain: AUEffectsChain) {
        self.id = UUID()
        self.name = name
        self.chain = chain
        self.createdAt = Date()
    }
}

extension AUEffectsPreset: Defaults.Serializable {}

// MARK: - AUEffectNode Equatable

extension AUEffectNode: Equatable {
    public static func == (lhs: AUEffectNode, rhs: AUEffectNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.effectType == rhs.effectType &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.parameters == rhs.parameters
    }
}

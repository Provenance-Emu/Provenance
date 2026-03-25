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
    /// Master enable toggle. When false, the entire chain is bypassed.
    public var isEnabled: Bool

    public static let empty = AUEffectsChain(nodes: [], isEnabled: false)

    public init(nodes: [AUEffectNode] = [], isEnabled: Bool = false) {
        self.nodes = nodes
        self.isEnabled = isEnabled
    }

    /// Returns true when the chain has at least one enabled node and the master switch is on.
    public var hasActiveEffects: Bool {
        isEnabled && nodes.contains { $0.isEnabled }
    }

    /// Returns only the nodes that are currently active.
    public var activeNodes: [AUEffectNode] {
        guard isEnabled else { return [] }
        return nodes.filter(\.isEnabled)
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

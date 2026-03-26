//
//  AUEffectNode.swift
//  PVCoreAudio
//
//  Created by Claude on 3/25/26.
//  Part of #3489 — AU filter support
//

import Foundation

/// A single effect node in the audio effects chain.
/// Stores the effect type, per-parameter values, and an enable/bypass flag.
public struct AUEffectNode: Codable, Identifiable, Sendable {
    public var id: UUID
    public var effectType: AUEffectType
    /// Whether this node is active (not bypassed).
    public var isEnabled: Bool
    /// Parameter values keyed by `AUEffectParameterKey` constants.
    public var parameters: [String: Double]

    public init(effectType: AUEffectType, isEnabled: Bool = true) {
        self.id = UUID()
        self.effectType = effectType
        self.isEnabled = isEnabled
        self.parameters = effectType.defaultParameters
    }
}

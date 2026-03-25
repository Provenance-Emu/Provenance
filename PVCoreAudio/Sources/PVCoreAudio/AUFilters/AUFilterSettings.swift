//
//  AUFilterSettings.swift
//  PVCoreAudio
//
//  Created by Claude on 3/25/26.
//  Part of #3489 — AU filter support
//

import Foundation
import Defaults
import PVSettings

// MARK: - Defaults Keys

public extension Defaults.Keys {
    /// Whether the AU effects chain post-processor is enabled.
    static let auFiltersEnabled = Key<Bool>("auFiltersEnabled", default: false)

    /// The active effects chain applied to emulator audio output.
    static let auEffectsChain = Key<AUEffectsChain>("auEffectsChain", default: .empty)

    /// User-saved effects chain presets.
    static let auEffectsPresets = Key<[AUEffectsPreset]>("auEffectsPresets", default: [])
}

// MARK: - Built-in Presets

public extension AUEffectsPreset {
    /// Factory preset: adds light reverb to simulate a small room.
    static let builtinRoom: AUEffectsPreset = {
        var reverb = AUEffectNode(effectType: .reverb)
        reverb.parameters[AUEffectParameterKey.wetDryMix] = 15.0
        return AUEffectsPreset(name: "Room Reverb", chain: AUEffectsChain(nodes: [reverb], isEnabled: true))
    }()

    /// Factory preset: retro echo suitable for chiptune/FM music.
    static let builtinRetroEcho: AUEffectsPreset = {
        var delay = AUEffectNode(effectType: .delay)
        delay.parameters[AUEffectParameterKey.delayTime] = 0.1
        delay.parameters[AUEffectParameterKey.feedback] = 40.0
        delay.parameters[AUEffectParameterKey.wetDryMix] = 25.0
        return AUEffectsPreset(name: "Retro Echo", chain: AUEffectsChain(nodes: [delay], isEnabled: true))
    }()

    /// Factory preset: warm low-pass filter to soften high-frequency harshness.
    static let builtinWarm: AUEffectsPreset = {
        var lp = AUEffectNode(effectType: .lowPassFilter)
        lp.parameters[AUEffectParameterKey.cutoffFrequency] = 8000.0
        lp.parameters[AUEffectParameterKey.resonance] = 2.0
        return AUEffectsPreset(name: "Warm", chain: AUEffectsChain(nodes: [lp], isEnabled: true))
    }()

    /// Factory preset: lo-fi distortion to approximate older hardware output.
    static let builtinLoFi: AUEffectsPreset = {
        var lp = AUEffectNode(effectType: .lowPassFilter)
        lp.parameters[AUEffectParameterKey.cutoffFrequency] = 6000.0
        var dist = AUEffectNode(effectType: .distortion)
        dist.parameters[AUEffectParameterKey.preGain] = 4.0
        dist.parameters[AUEffectParameterKey.wetDryMix] = 15.0
        return AUEffectsPreset(name: "Lo-Fi", chain: AUEffectsChain(nodes: [lp, dist], isEnabled: true))
    }()

    /// All factory presets in display order.
    static let builtinPresets: [AUEffectsPreset] = [
        .builtinRoom,
        .builtinRetroEcho,
        .builtinWarm,
        .builtinLoFi
    ]
}

// MARK: - ObjC bridge

@objc
public extension PVSettingsWrapper {
    @objc static var auFiltersEnabled: Bool {
        get { Defaults[.auFiltersEnabled] }
        set { Defaults[.auFiltersEnabled] = newValue }
    }
}

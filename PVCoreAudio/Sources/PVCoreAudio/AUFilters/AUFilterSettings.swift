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

/// # Why these keys use the closure (`default:` getter) initializer
///
/// `Defaults.Key.init(_:default:suite:iCloud:)` — the *value* overload — ends in
/// `UserDefaults.register(defaults:)`, which posts `UserDefaults.didChangeNotification`.
/// Block-based observers registered with an `OperationQueue` (this app has several on
/// that notification, e.g. `ControllerLightBarManager` / `GCControllerHapticsManager`,
/// both `queue: .main`) are delivered by wrapping the block in an `NSOperation` and
/// **blocking the posting thread** until the operation finishes
/// (`_CFXNotificationPost` → `-[NSOperation waitUntilFinished]`).
///
/// Swift runs a `static let` initializer under `swift_once`. Combining the two means
/// the first touch of one of these keys *from a background thread* parks that thread
/// **while it owns the once token**, waiting on the main queue. If the main thread then
/// reads the same key it blocks in `_dispatch_once_wait` — and the main queue can never
/// drain, so the token is never released. That is a hard deadlock; it shipped as an
/// `0x8BADF00D` watchdog kill on game launch (main thread in
/// `AVAudioEngineGameAudioEngine.updateSourceNode()` waiting on the `auEffectsChain`
/// and `auFiltersEnabled` tokens, both owned by parked cooperative-pool threads).
///
/// The closure overload is documented to *not* write the default into `UserDefaults`,
/// so the once block becomes pure: it allocates the `Key` and returns. There is nothing
/// left inside it that can block, so it can never be held by a parked thread.
///
/// Reads are unaffected: `Defaults[key]` is `suite._get(name) ?? key.defaultValue`, and
/// `Defaults.updates(_:)` falls back to `key.defaultValue` the same way, so an
/// unregistered key still resolves to the default until the user stores a value.
///
/// - Important: Every `Defaults.Key` declared in PVCoreAudio uses this form. Audio keys
///   are read from the emulation/audio threads and from `notify`/route-change callbacks,
///   so none of them may register from a background thread.
public extension Defaults.Keys {
    /// Whether the AU effects chain post-processor is enabled.
    static let auFiltersEnabled = Key<Bool>("auFiltersEnabled", default: { false })

    /// The active effects chain applied to emulator audio output.
    static let auEffectsChain = Key<AUEffectsChain>("auEffectsChain", default: { .empty })

    /// User-saved effects chain presets.
    static let auEffectsPresets = Key<[AUEffectsPreset]>("auEffectsPresets", default: { [] })
}

// MARK: - Built-in Presets

public extension AUEffectsPreset {
    /// Factory preset: adds light reverb to simulate a small room.
    static let builtinRoom: AUEffectsPreset = {
        var reverb = AUEffectNode(effectType: .reverb)
        reverb.parameters[AUEffectParameterKey.wetDryMix] = 15.0
        return AUEffectsPreset(name: "Room Reverb", chain: AUEffectsChain(nodes: [reverb]))
    }()

    /// Factory preset: retro echo suitable for chiptune/FM music.
    static let builtinRetroEcho: AUEffectsPreset = {
        var delay = AUEffectNode(effectType: .delay)
        delay.parameters[AUEffectParameterKey.delayTime] = 0.1
        delay.parameters[AUEffectParameterKey.feedback] = 40.0
        delay.parameters[AUEffectParameterKey.wetDryMix] = 25.0
        return AUEffectsPreset(name: "Retro Echo", chain: AUEffectsChain(nodes: [delay]))
    }()

    /// Factory preset: warm low-pass filter to soften high-frequency harshness.
    static let builtinWarm: AUEffectsPreset = {
        var lp = AUEffectNode(effectType: .lowPassFilter)
        lp.parameters[AUEffectParameterKey.cutoffFrequency] = 8000.0
        lp.parameters[AUEffectParameterKey.resonance] = 2.0
        return AUEffectsPreset(name: "Warm", chain: AUEffectsChain(nodes: [lp]))
    }()

    /// Factory preset: lo-fi distortion to approximate older hardware output.
    static let builtinLoFi: AUEffectsPreset = {
        var lp = AUEffectNode(effectType: .lowPassFilter)
        lp.parameters[AUEffectParameterKey.cutoffFrequency] = 6000.0
        var dist = AUEffectNode(effectType: .distortion)
        dist.parameters[AUEffectParameterKey.preGain] = 4.0
        dist.parameters[AUEffectParameterKey.wetDryMix] = 15.0
        return AUEffectsPreset(name: "Lo-Fi", chain: AUEffectsChain(nodes: [lp, dist]))
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

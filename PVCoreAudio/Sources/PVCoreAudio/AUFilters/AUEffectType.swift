//
//  AUEffectType.swift
//  PVCoreAudio
//
//  Created by Claude on 3/25/26.
//  Part of #3489 — AU filter support
//

import Foundation
import AudioToolbox
import AVFoundation

/// Audio Unit effect types available for the emulation post-processing chain.
/// Covers retro-style effects (reverb, delay, distortion) plus utility effects
/// (EQ, dynamics). All types use built-in Apple Audio Units available on iOS/tvOS.
public enum AUEffectType: String, Codable, CaseIterable, CustomStringConvertible, Sendable {
    case reverb
    case delay
    case distortion
    case lowPassFilter
    case highPassFilter
    case bandPassFilter
    case parametricEQ
    case peakLimiter
    case dynamicsProcessor

    public var description: String {
        switch self {
        case .reverb:             return "Reverb"
        case .delay:              return "Delay / Echo"
        case .distortion:         return "Distortion"
        case .lowPassFilter:      return "Low Pass Filter"
        case .highPassFilter:     return "High Pass Filter"
        case .bandPassFilter:     return "Band Pass Filter"
        case .parametricEQ:       return "Parametric EQ"
        case .peakLimiter:        return "Peak Limiter"
        case .dynamicsProcessor:  return "Dynamics Processor"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .reverb:             return "waveform.badge.plus"
        case .delay:              return "waveform.path.ecg"
        case .distortion:         return "waveform.badge.exclamationmark"
        case .lowPassFilter:      return "arrow.down.to.line"
        case .highPassFilter:     return "arrow.up.to.line"
        case .bandPassFilter:     return "slider.horizontal.3"
        case .parametricEQ:       return "waveform"
        case .peakLimiter:        return "speaker.wave.3"
        case .dynamicsProcessor:  return "waveform.path"
        }
    }

    /// Audio Unit component description for this effect.
    public var componentDescription: AudioComponentDescription {
        switch self {
        case .reverb:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_Reverb2,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .delay:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_Delay,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .distortion:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_Distortion,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .lowPassFilter:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_LowPassFilter,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .highPassFilter:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_HighPassFilter,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .bandPassFilter:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_BandPassFilter,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .parametricEQ:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_ParametricEQ,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .peakLimiter:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_PeakLimiter,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        case .dynamicsProcessor:
            return AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        }
    }

    /// Default parameter values for each effect type.
    public var defaultParameters: [String: Double] {
        switch self {
        case .reverb:
            return [
                AUEffectParameterKey.wetDryMix: 20.0
            ]
        case .delay:
            return [
                AUEffectParameterKey.delayTime: 0.25,
                AUEffectParameterKey.feedback: 50.0,
                AUEffectParameterKey.lowPassCutoff: 15000.0,
                AUEffectParameterKey.wetDryMix: 30.0
            ]
        case .distortion:
            return [
                AUEffectParameterKey.preGain: 6.0,
                AUEffectParameterKey.wetDryMix: 25.0
            ]
        case .lowPassFilter:
            return [
                AUEffectParameterKey.cutoffFrequency: 1000.0,
                AUEffectParameterKey.resonance: 0.0
            ]
        case .highPassFilter:
            return [
                AUEffectParameterKey.cutoffFrequency: 80.0,
                AUEffectParameterKey.resonance: 0.0
            ]
        case .bandPassFilter:
            return [
                AUEffectParameterKey.centerFrequency: 1000.0,
                AUEffectParameterKey.bandwidth: 1.0
            ]
        case .parametricEQ:
            return [
                AUEffectParameterKey.centerFrequency: 1000.0,
                AUEffectParameterKey.qFactor: 1.0,
                AUEffectParameterKey.gain: 0.0
            ]
        case .peakLimiter:
            return [
                AUEffectParameterKey.attackTime: 0.001,
                AUEffectParameterKey.decayTime: 0.01,
                AUEffectParameterKey.preGain: 0.0
            ]
        case .dynamicsProcessor:
            return [
                AUEffectParameterKey.threshold: -20.0,
                AUEffectParameterKey.headRoom: 5.0,
                AUEffectParameterKey.attackTime: 0.001,
                AUEffectParameterKey.releaseTime: 0.05
            ]
        }
    }

    /// Parameter definitions for UI display — (key, display name, min, max, unit).
    public var parameterDefinitions: [AUEffectParameterDefinition] {
        switch self {
        case .reverb:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.wetDryMix, name: "Mix", min: 0, max: 100, unit: "%")
            ]
        case .delay:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.delayTime, name: "Delay Time", min: 0, max: 2, unit: "s"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.feedback, name: "Feedback", min: 0, max: 100, unit: "%"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.lowPassCutoff, name: "Low Pass Cutoff", min: 10, max: 22050, unit: "Hz"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.wetDryMix, name: "Mix", min: 0, max: 100, unit: "%")
            ]
        case .distortion:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.preGain, name: "Pre-Gain", min: -40, max: 40, unit: "dB"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.wetDryMix, name: "Mix", min: 0, max: 100, unit: "%")
            ]
        case .lowPassFilter:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.cutoffFrequency, name: "Cutoff", min: 10, max: 22050, unit: "Hz"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.resonance, name: "Resonance", min: -20, max: 40, unit: "dB")
            ]
        case .highPassFilter:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.cutoffFrequency, name: "Cutoff", min: 10, max: 22050, unit: "Hz"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.resonance, name: "Resonance", min: -20, max: 40, unit: "dB")
            ]
        case .bandPassFilter:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.centerFrequency, name: "Center Freq", min: 20, max: 22050, unit: "Hz"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.bandwidth, name: "Bandwidth", min: 0.05, max: 5.0, unit: "oct")
            ]
        case .parametricEQ:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.centerFrequency, name: "Frequency", min: 20, max: 22050, unit: "Hz"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.qFactor, name: "Q", min: 0.1, max: 20, unit: ""),
                AUEffectParameterDefinition(key: AUEffectParameterKey.gain, name: "Gain", min: -20, max: 20, unit: "dB")
            ]
        case .peakLimiter:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.attackTime, name: "Attack", min: 0.001, max: 0.03, unit: "s"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.decayTime, name: "Decay", min: 0.001, max: 0.06, unit: "s"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.preGain, name: "Pre-Gain", min: -40, max: 40, unit: "dB")
            ]
        case .dynamicsProcessor:
            return [
                AUEffectParameterDefinition(key: AUEffectParameterKey.threshold, name: "Threshold", min: -40, max: 20, unit: "dB"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.headRoom, name: "Head Room", min: 0.1, max: 40, unit: "dB"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.attackTime, name: "Attack", min: 0.0001, max: 0.2, unit: "s"),
                AUEffectParameterDefinition(key: AUEffectParameterKey.releaseTime, name: "Release", min: 0.01, max: 3, unit: "s")
            ]
        }
    }

    /// Creates an AVAudioUnit for this effect type and applies the given parameters.
    public func makeAVAudioUnit(parameters: [String: Double]) -> AVAudioUnit? {
        switch self {
        case .reverb:
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = Float(parameters[AUEffectParameterKey.wetDryMix] ?? 20.0)
            return reverb

        case .delay:
            let delay = AVAudioUnitDelay()
            delay.delayTime = parameters[AUEffectParameterKey.delayTime] ?? 0.25
            delay.feedback = Float(parameters[AUEffectParameterKey.feedback] ?? 50.0)
            delay.lowPassCutoff = Float(parameters[AUEffectParameterKey.lowPassCutoff] ?? 15000.0)
            delay.wetDryMix = Float(parameters[AUEffectParameterKey.wetDryMix] ?? 30.0)
            return delay

        case .distortion:
            let distortion = AVAudioUnitDistortion()
            distortion.loadFactoryPreset(.multiBrokenSpeaker)
            distortion.preGain = Float(parameters[AUEffectParameterKey.preGain] ?? 6.0)
            distortion.wetDryMix = Float(parameters[AUEffectParameterKey.wetDryMix] ?? 25.0)
            return distortion

        case .lowPassFilter, .highPassFilter, .bandPassFilter, .parametricEQ, .peakLimiter, .dynamicsProcessor:
            return makeFilterUnit(parameters: parameters)
        }
    }

    /// Returns an AVAudioUnit for filter/dynamics types that lack a high-level AVFoundation wrapper.
    /// EQ-based types use AVAudioUnitEQ; peakLimiter/dynamicsProcessor use AVAudioUnitEffect
    /// and apply parameters via the AU parameter tree using Apple-defined parameter addresses.
    private func makeFilterUnit(parameters: [String: Double]) -> AVAudioUnit? {
        switch self {
        case .lowPassFilter:
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            let band = eq.bands[0]
            band.filterType = .lowPass
            band.frequency = Float(parameters[AUEffectParameterKey.cutoffFrequency] ?? 1000.0)
            band.bandwidth = 1.0
            band.gain = Float(parameters[AUEffectParameterKey.resonance] ?? 0.0)
            band.bypass = false
            return eq

        case .highPassFilter:
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            let band = eq.bands[0]
            band.filterType = .highPass
            band.frequency = Float(parameters[AUEffectParameterKey.cutoffFrequency] ?? 80.0)
            band.bandwidth = 1.0
            band.gain = Float(parameters[AUEffectParameterKey.resonance] ?? 0.0)
            band.bypass = false
            return eq

        case .bandPassFilter:
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            let band = eq.bands[0]
            band.filterType = .bandPass
            band.frequency = Float(parameters[AUEffectParameterKey.centerFrequency] ?? 1000.0)
            band.bandwidth = Float(parameters[AUEffectParameterKey.bandwidth] ?? 1.0)
            band.bypass = false
            return eq

        case .parametricEQ:
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            let band = eq.bands[0]
            band.filterType = .parametric
            band.frequency = Float(parameters[AUEffectParameterKey.centerFrequency] ?? 1000.0)
            let q = parameters[AUEffectParameterKey.qFactor] ?? 1.0
            let bwOctaves = 2.0 * asinh(1.0 / (2.0 * q)) / log(2.0)
            band.bandwidth = Float(bwOctaves)
            band.gain = Float(parameters[AUEffectParameterKey.gain] ?? 0.0)
            band.bypass = false
            return eq

        case .peakLimiter:
            let effect = AVAudioUnitEffect(audioComponentDescription: componentDescription)
            // Apply parameters via the AU parameter tree using Apple-defined constants from
            // <AudioUnit/AudioUnitParameters.h>: kLimiterParam_AttackTime=0, DecayTime=1, PreGain=2
            if let tree = effect.auAudioUnit.parameterTree {
                let addressMap: [AUParameterAddress: Double] = [
                    AUParameterAddress(kLimiterParam_AttackTime): parameters[AUEffectParameterKey.attackTime] ?? 0.001,
                    AUParameterAddress(kLimiterParam_DecayTime): parameters[AUEffectParameterKey.decayTime] ?? 0.01,
                    AUParameterAddress(kLimiterParam_PreGain): parameters[AUEffectParameterKey.preGain] ?? 0.0
                ]
                for param in tree.allParameters {
                    if let value = addressMap[param.address] {
                        param.value = AUValue(value)
                    }
                }
            }
            return effect

        case .dynamicsProcessor:
            let effect = AVAudioUnitEffect(audioComponentDescription: componentDescription)
            // Apply parameters via the AU parameter tree using Apple-defined constants from
            // <AudioUnit/AudioUnitParameters.h>: Threshold=0, HeadRoom=1, AttackTime=4, ReleaseTime=5
            if let tree = effect.auAudioUnit.parameterTree {
                let addressMap: [AUParameterAddress: Double] = [
                    AUParameterAddress(kDynamicsProcessorParam_Threshold): parameters[AUEffectParameterKey.threshold] ?? -20.0,
                    AUParameterAddress(kDynamicsProcessorParam_HeadRoom): parameters[AUEffectParameterKey.headRoom] ?? 5.0,
                    AUParameterAddress(kDynamicsProcessorParam_AttackTime): parameters[AUEffectParameterKey.attackTime] ?? 0.001,
                    AUParameterAddress(kDynamicsProcessorParam_ReleaseTime): parameters[AUEffectParameterKey.releaseTime] ?? 0.05
                ]
                for param in tree.allParameters {
                    if let value = addressMap[param.address] {
                        param.value = AUValue(value)
                    }
                }
            }
            return effect

        default:
            return nil
        }
    }
}

// MARK: - Parameter Keys

/// String key constants for AUEffectNode parameter dictionaries.
public enum AUEffectParameterKey {
    public static let wetDryMix         = "wetDryMix"
    public static let delayTime         = "delayTime"
    public static let feedback          = "feedback"
    public static let lowPassCutoff     = "lowPassCutoff"
    public static let preGain           = "preGain"
    public static let cutoffFrequency   = "cutoffFrequency"
    public static let resonance         = "resonance"
    public static let centerFrequency   = "centerFrequency"
    public static let bandwidth         = "bandwidth"
    public static let qFactor           = "qFactor"
    public static let gain              = "gain"
    public static let attackTime        = "attackTime"
    public static let decayTime         = "decayTime"
    public static let releaseTime       = "releaseTime"
    public static let threshold         = "threshold"
    public static let headRoom          = "headRoom"
}

// MARK: - Parameter Definition

/// Metadata for a single adjustable parameter — used to build the settings UI.
public struct AUEffectParameterDefinition: Sendable {
    public let key: String
    public let name: String
    public let min: Double
    public let max: Double
    public let unit: String

    public init(key: String, name: String, min: Double, max: Double, unit: String) {
        self.key = key
        self.name = name
        self.min = min
        self.max = max
        self.unit = unit
    }
}

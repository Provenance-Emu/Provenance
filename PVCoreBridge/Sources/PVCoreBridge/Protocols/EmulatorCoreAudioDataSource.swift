//
//  EmulatorCoreAudioDataSource.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import PVAudio
import RingBuffer
import Foundation

@objc public protocol EmulatorCoreAudioDataSource {

    @objc var frameInterval: TimeInterval { get }
    @objc weak var audioDelegate: PVAudioDelegate? { get set }

    @objc var audioSampleRate: Double { get set }
    @objc var audioBitDepth: UInt { get }
    @objc dynamic var channelCount: UInt { get }

    @objc dynamic var audioBufferCount: UInt { get }

    @objc func channelCount(forBuffer: UInt) -> UInt
    @objc func audioBufferSize(forBuffer: UInt) -> UInt
    @objc func audioSampleRate(forBuffer: UInt) -> Double

    @objc var ringBuffers: [RingBufferProtocol]? { get set }
    @objc func ringBuffer(atIndex: UInt) -> RingBufferProtocol?
}

@objc public protocol EmulatorCoreAudioDelegate {
    @objc func audioSampleRateDidChange();
}

/// Optional: Bridges that can provide waveform data for visualizers
@objc public protocol EmulatorCoreWaveformProvider {
    @objc func installWaveformTap()
    @objc func removeWaveformTap()
    @objc func dequeueWaveformAmplitudes(withMaxCount: UInt) -> [NSNumber]
    /// Copy up to maxCount amplitudes into the provided buffer. Returns number of samples written.
    /// Matches Objective‑C selector `copyWaveformAmplitudesTo:maxCount:` implemented in bridges.
    @objc(copyWaveformAmplitudesTo:maxCount:)
    func copyWaveformAmplitudes(to outBuffer: UnsafeMutablePointer<Float>, maxCount: UInt) -> UInt
}

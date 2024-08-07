//
//  EmulatorCoreAudioDataSource.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import PVAudio

@objc
public protocol EmulatorCoreAudioDataSource: Sendable {

    @objc var frameInterval: TimeInterval { get }
    @objc var audioDelegate: PVAudioDelegate? { get set }

    var sampleRate: Double { get }
    var audioBitDepth: UInt { get }
    var channelCount: UInt { get }

    var audioBufferCount: UInt { get }

    func channelCount(forBuffer: UInt) -> UInt
    func audioBufferSize(forBuffer: UInt) -> UInt
    func audioSampleRate(forBuffer: UInt) -> Double

    var ringBuffers: [RingBuffer]? { get set }
    func ringBuffer(atIndex: UInt) -> RingBuffer?
}

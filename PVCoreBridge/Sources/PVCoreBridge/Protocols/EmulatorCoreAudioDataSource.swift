//
//  EmulatorCoreAudioDataSource.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import PVAudio
import Foundation

@objc public protocol EmulatorCoreAudioDataSource: Sendable {

    @objc var frameInterval: TimeInterval { get }
    @objc var audioDelegate: PVAudioDelegate? { get set }

    var sampleRate: Double { get set }
    var audioBitDepth: UInt { get }
    var channelCount: UInt { get }

    var audioBufferCount: UInt { get }

    func channelCount(forBuffer: UInt) -> UInt
    func audioBufferSize(forBuffer: UInt) -> UInt
    func audioSampleRate(forBuffer: UInt) -> Double

    var ringBuffers: [RingBuffer]? { get set }
    func ringBuffer(atIndex: UInt) -> RingBuffer?
}

@objc public protocol EmulatorCoreAudioDelegate {
    func audioSampleRateDidChange();
}

public extension EmulatorCoreAudioDataSource {

    var frameInterval: TimeInterval {  1/60.0 }

    var sampleRate: Double { 48000.00 }
    var audioBitDepth: UInt { 16 }
    var channelCount: UInt { 1 }

    var audioBufferCount: UInt { 1 }

    func channelCount(forBuffer buffer: UInt) -> UInt {
        if buffer == 0 {
            return channelCount
        } else {
            return 0
        }
    }

    func audioBufferSize(forBuffer buffer: UInt) -> UInt {
        // 4 frames is a complete guess
        let frameSampleCount = audioSampleRate(forBuffer: buffer) / frameInterval
        let channelCount = channelCount(forBuffer:buffer)
        let bytesPerSample = audioBitDepth / 8
        //    NSAssert(frameSampleCount, @"frameSampleCount is 0");
        return channelCount * bytesPerSample * UInt(frameSampleCount)
    }

    func ringBuffer(atIndex index: UInt) -> RingBuffer {
        let index: Int = Int(index)
        if ringBuffers == nil || ringBuffers!.count < index + 1 {
            let length: Int = Int(audioBufferSize(forBuffer: UInt(index)) * audioBitDepth)

            ringBuffers = .init(repeating:  RingBuffer.init(withLength: length)!, count: Int(audioBufferCount))
        }

        guard let ringBuffer = ringBuffers?[index] else {
            let length: Int = Int(audioBufferSize(forBuffer: UInt(index)) * audioBitDepth)
            let newRingBuffer: RingBuffer = RingBuffer.init(withLength: length)!
            ringBuffers?[Int(index)] = newRingBuffer
            return newRingBuffer
        }
        return ringBuffer
    }
}

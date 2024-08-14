//
//  PVEmulatorCore.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio

//@_objcImplementation(EmulatorCoreAudioDataSource)
@objc
extension PVEmulatorCore: EmulatorCoreAudioDataSource {

    @objc open var frameInterval: TimeInterval {
        if let objcBridge: ObjCCoreBridge = self as? ObjCCoreBridge {
            return objcBridge.frameInterval
        } else {
            return (self as EmulatorCoreAudioDataSource).frameInterval
        }
    }

    @objc open var sampleRate: Double { 48000.00 }
    @objc open var audioBitDepth: UInt { 16 }
    @objc open var channelCount: UInt { 1 }

    @objc open var audioBufferCount: UInt { 1 }

    @objc public func getAudioBuffer(_ buffer: UnsafeMutableRawPointer, frameCount: UInt32, bufferIndex index: UInt) {
        let channelCount = channelCount(forBuffer: index)
        let maxLength = UInt(frameCount) * channelCount * audioBitDepth
        ringBuffer(atIndex: index)?.read(into: buffer, preferredSize: Int(maxLength))
    }

    @objc public func channelCount(forBuffer buffer: UInt) -> UInt {
        if buffer == 0 {
            return channelCount
        } else {
            return 0
        }
    }
    
    @objc public func audioBufferSize(forBuffer buffer: UInt) -> UInt {
        // 4 frames is a complete guess
        let frameSampleCount = audioSampleRate(forBuffer: buffer) / frameInterval
        let channelCount = channelCount(forBuffer:buffer)
        let bytesPerSample = audioBitDepth / 8
        //    NSAssert(frameSampleCount, @"frameSampleCount is 0");
        return channelCount * bytesPerSample * UInt(frameSampleCount)
    }

    @objc  public func ringBuffer(atIndex index: UInt) -> RingBuffer? {
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

    @objc public func audioSampleRate(forBuffer buffer: UInt = 0) -> Double {
        if buffer == 0 {
            return sampleRate
        }

        ELOG("Buffer count is greater than 1, must implement audioSampleRate(forBuffer)")
        return 0
    }
}

#if !os(tvOS) && !os(macOS)
import AVFAudio
internal extension PVEmulatorCore {
    func getSampleRate() -> Float64 {
        return AVAudioSession.sharedInstance().sampleRate
    }

    func setPreferredSampleRate(_ preferredSampleRate: Double) throws {
        let preferredSampleRate: Double = (self.sampleRate > 0) ? self.sampleRate : 48000
        try AVAudioSession.sharedInstance().setPreferredSampleRate(preferredSampleRate)
    }
}
#endif

//
//  PVEmulatorCore.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVAudio

//@_objcImplementation(EmulatorCoreAudioDataSource)
extension PVEmulatorCore: EmulatorCoreAudioDataSource {

    @objc dynamic open var frameInterval: TimeInterval {
        if let objcBridge: any ObjCBridgedCore = self as? (any ObjCBridgedCore),
            let bridge = objcBridge.bridge as? any ObjCBridgedCoreBridge & EmulatorCoreAudioDataSource,
            bridge.responds(to: #selector(getter: bridge.frameInterval)) {
            let frameInterval = bridge.frameInterval
            return frameInterval
        } else {
            return 60.0
        }
    }

    @objc dynamic  open var sampleRate: Double {
        get {
            if let objcBridge: any ObjCBridgedCore = self as? (any ObjCBridgedCore),
                let bridge = objcBridge.bridge as? any ObjCBridgedCoreBridge & EmulatorCoreAudioDataSource,
                bridge.responds(to: #selector(getter: bridge.sampleRate)) {
                let sampleRate = bridge.sampleRate
                return sampleRate
            } else {
                return 44100.0
            }
        }
        set {
            if let objcBridge: any ObjCBridgedCore = self as? (any ObjCBridgedCore),
                let bridge = objcBridge.bridge as? any ObjCBridgedCoreBridge & EmulatorCoreAudioDataSource,
                bridge.responds(to: #selector(setter: bridge.sampleRate)) {
                bridge.sampleRate = newValue
            } else {
                fatalError("Should be overridden by subclass")
            }
        }
    }
    @objc dynamic  open var audioBitDepth: UInt {
        get {
            if let objcBridge: any ObjCBridgedCore = self as? (any ObjCBridgedCore),
                let bridge = objcBridge.bridge as? any ObjCBridgedCoreBridge & EmulatorCoreAudioDataSource,
                bridge.responds(to: #selector(getter: bridge.audioBitDepth)) {
                let audioBitDepth = bridge.audioBitDepth
                return audioBitDepth
            } else {
                return 16
            }
        }
//        set {
//            // use objc stored property
//            if let objcBridge: ObjCCoreBridge = self as? ObjCCoreBridge {
//                return objcBridge.audioBitDepth = newValue
//            } else {
//                fatalError("Should be overridden by subclass")
//            }
//        }
    }
    @objc dynamic open var channelCount: UInt {
        let channelCount = bridge.channelCount ?? 1
        DLOG("channelCount: \(channelCount)")
        return channelCount
    }

    @objc dynamic open var audioBufferCount: UInt {
        bridge.audioBufferCount ?? 1
    }

    @objc public func getAudioBuffer(_ buffer: UnsafeMutableRawPointer, frameCount: UInt32, bufferIndex index: UInt) {
        let channelCount = channelCount(forBuffer: index)
        let maxLength = UInt(frameCount) * channelCount * audioBitDepth
        ringBuffer(atIndex: index)?.read(buffer, preferredSize: Int(maxLength))
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
        let frameInterval = self.frameInterval
        let audioSampleRate = audioSampleRate(forBuffer: buffer)
        let frameSampleCount = audioSampleRate / frameInterval
        let channelCount = channelCount(forBuffer:buffer)
        let bytesPerSample = audioBitDepth / 8
        //    NSAssert(frameSampleCount, @"frameSampleCount is 0");
        return channelCount * bytesPerSample * UInt(frameSampleCount)
    }

    @objc public func ringBuffer(atIndex index: UInt) -> RingBufferProtocol? {
        bridge.ringBuffer(atIndex: index)
//        let index: Int = Int(index)
//        if ringBuffers == nil || ringBuffers!.count < index + 1 {
//            let length: Int = Int(audioBufferSize(forBuffer: UInt(index)) * audioBitDepth)
//
//            ringBuffers = .init(repeating:  RingBuffer.init(withLength: length)!, count: Int(audioBufferCount))
//        }
//
//        guard let ringBuffer = ringBuffers?[index] else {
//            let length: Int = Int(audioBufferSize(forBuffer: UInt(index)) * audioBitDepth)
//            let newRingBuffer: RingBuffer = RingBuffer.init(withLength: length)!
//            ringBuffers?[Int(index)] = newRingBuffer
//            return newRingBuffer
//        }
//        return ringBuffer
    }

    @objc public func audioSampleRate(forBuffer buffer: UInt = 0) -> Double {
        if buffer == 0 {
            return sampleRate
        }

        ELOG("Buffer count is greater than 1, must implement audioSampleRate(forBuffer)")
        return 0
    }
}

#if !os(tvOS) && !os(macOS) && !os(watchOS)
import AVFAudio
internal extension PVEmulatorCore {
    func getSampleRate() -> Float64 {
        return AVAudioSession.sharedInstance().sampleRate
    }

    func setPreferredSampleRate(_ preferredSampleRate: Double) throws {
        let preferredSampleRate: Double = (self.sampleRate > 0) ? self.sampleRate : 44100
        try AVAudioSession.sharedInstance().setPreferredSampleRate(preferredSampleRate)
    }
}
#endif

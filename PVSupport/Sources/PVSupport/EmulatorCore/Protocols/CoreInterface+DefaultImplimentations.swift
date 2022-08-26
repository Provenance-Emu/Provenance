//
//  CoreInterface+DefaultImplimentations.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/25/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
#if !os(tvOS) && !os(macOS)
import AVFoundation
import AVFAudio
import AVKit
#endif

// TODO: FrameInterval should be called, frameRate everywhere since we use fps, not 1/fps
fileprivate let defaultFrameInterval: TimeInterval = 60.0  //1.0 / 60.0

public
extension CoreInterface {
    var gameInterval: TimeInterval {
        return 1.0 / emulationFPS
    }
    var frameInterval: TimeInterval {
        // TODO: This is the proper math for interval, we're using the wrong term, we mean fps
        //        return renderFPS > 0 ? 1.0 / renderFPS : defaultFrameInterval
        return renderFPS > 0 ? renderFPS : defaultFrameInterval
    }
}

public
extension CoreInterface {
    var isRunning: Bool {
        return !shouldStop
    }
    var romName: String? {
        return nil
    }
    var saveStatesPath: String? {
        return nil
    }
    var batterySavesPath: String? {
        return nil
    }
    var BIOSPath: String? {
        return nil
    }
    var systemIdentifier: String? {
        return nil
    }
    var coreIdentifier: String? {
        return nil
    }
    var romMD5: String? {
        return nil
    }
    var romSerial: String? {
        return nil
    }
    var supportsSaveStates: Bool {
        return false
    }
    var supportsRumble: Bool {
        return false
    }
    var shouldResyncTime: Bool {
        get {
            return false
        }
        set {
            // do nothing
        }
    }
    var gameSpeed: GameSpeed {
        return .normal
    }
    var isSpeedModified: Bool {
        gameSpeed != .normal
    }
    var controller1: GCController? {
        return nil
    }
    var controller2: GCController? {
        return nil
    }
    var controller3: GCController? {
        return nil
    }
    var controller4: GCController? {
        return nil
    }
    var emulationLoopThreadLock: NSLock {
        return NSLock()
    }
    var frontBufferCondition: NSCondition {
        return NSCondition()
    }
    var frontBufferLock: NSLock {
        return NSLock()
    }
    var isFrontBufferReady: Bool {
        return false
    }
    var glesVersion: GLESVersion {
        return .gles3
    }
    var depthFormat: GLenum {
        return 0 //GLenum(GL_DEPTH_COMPONENT16)
    }
    var screenRect: CGRect {
        return CGRect.zero
    }
    var aspectSize: CGSize {
        return CGSize.zero
    }
}

public
extension CoreInterface {
    var bufferSize: CGSize {
        return CGSize.zero
    }
    var isDoubleBuffered: Bool {
        return false
    }
    var rendersToOpenGL: Bool {
        return false
    }
    var pixelFormat: GLenum {
        return GLenum(GL_RGBA)
    }
    var pixelType: GLenum {
        return GLenum(GL_UNSIGNED_BYTE)
    }
    var internalPixelFormat: GLenum {
        return GLenum(GL_RGBA)
    }
    var audioSampleRate: Double {
        return 44100.0
    }
    var channelCount: Int {
        return 2
    }
    var audioBufferCount: UInt {
        return 1
    }
    var audioBitDepth: UInt {
        return 16
    }
    var isEmulationPaused: Bool {
        return !isRunning
    }
    var videoBuffer: UnsafeMutablePointer<UInt16>? {
        return nil
    }
}
public
extension CoreInterface {
    func startEmulation() {
        // do nothing
    }
    func setPauseEmulation(_ paused: Bool) {
        // do nothing
    }
    func stopEmulation() {
        // do nothing
    }
    func resetEmulation() {
        // do nothing
    }
    func executeFrame() {
        // do nothing
    }
    func loadFile(atPath path: String) throws {
        // do nothing
    }
    func updateControllers() {
        // do nothing
    }
    func swapBuffers() {
        // do nothing
        assert(!isDoubleBuffered, "Cores that are double-buffered must implement swapBuffers!")
    }
    func saveStateToFile(atPath path: String) throws {
        // do nothing
    }
    func loadStateToFile(atPath path: String) throws {
        // do nothing
    }
}

let AUDIO_SAMPLERATE_DEFAULT: Double = 44100.0

#if !os(tvOS) && !os(macOS)
public
extension CoreInterface {
    func setPreferredSampleRate(_ sampleRate: Double) throws {
        let preferredSampleRate = sampleRate > 0 ? sampleRate : AUDIO_SAMPLERATE_DEFAULT
        if preferredSampleRate != currentAVSessionSampleRate {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(preferredSampleRate)
        }
    }

    var currentAVSessionSampleRate: Double {
        return AVAudioSession.sharedInstance().sampleRate
    }
}
#endif

public
extension CoreInterface {
    func getAudioBuffer(_ buffer: UnsafeMutableRawPointer, frameCount: UInt32, bufferIndex: UInt) {
        // do nothing
    }
}

public
extension CoreInterface {
    func channelCount(forBuffer buffer: Int) -> Int {
        return buffer == 0 ? channelCount : 0
    }
    func audioBufferSize(forBuffer buffer: Int) -> Int {
        let frameSampleCount: Double = audioSampleRate(forBuffer: buffer) / frameInterval
        let channelCount: Int = channelCount(forBuffer: buffer)
        let bytesPerSample: Int = audioBitDepth / 8
        let bytesPerFrame: Int = bytesPerSample * Int(channelCount)
        let bytesPerSecond: Int = bytesPerFrame * Int(frameSampleCount)
        return bytesPerSecond
    }
    func audioSampleRate(forBuffer buffer: Int) -> Double {
        return buffer == 0 ? audioSampleRate : 0
    }
    func setAudioEnabled(_ enabled: Bool) {
        // do nothing
    }
}

public
extension CoreInterface {
    func setVideoBuffer(_ buffer: UnsafeMutablePointer<UInt16>) {
        // do nothing
    }
}

@objc
public extension NSErrorDomain {
    static let CoreInterfaceErrorDomain = "CoreInterfaceErrorDomain"
}
//
//@objc
//@dynamicCallable
//public final class CoreBridge: NSObject, CoreInterface {
//    public func dynamicallyCall(withArguments args: [[AnyBSON]]) async throws -> Any {
//        try await withCheckedThrowingContinuation { continuation in
//
//            continuation.resume(returning: bson)
//
//            continuation.resume(throwing: error ?? Realm.Error.callFailed)
//        }
//    }
//}

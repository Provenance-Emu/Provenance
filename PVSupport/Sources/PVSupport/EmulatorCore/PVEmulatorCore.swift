//
//  PVEmulatorCore.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 3/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import AVFAudio
import AVFoundation
#if canImport(CoreHaptics)
import CoreHaptics
#endif
import Foundation
import MachO
#if canImport(Metal)
import Metal
import MetalKit
#endif
#if canImport(QuartzCore)
import QuartzCore
#endif
#if canImport(OpenGLES)
import OpenGLES
#endif
#if canImport(OpenGL)
import OpenGL
import GLUT
#endif
#if canImport(UIKit)
import UIKit
#endif
import simd

public typealias SaveStateCompletion = () throws -> (Bool)

func PVTimestamp() -> TimeInterval {
    return timebase_ratio * 1.0e-09 * Double(mach_absolute_time())
}

func GetSecondsSince(_ time: TimeInterval) -> TimeInterval {
    // return PVTimestamp(CACurrentMediaTime()) - time
    return PVTimestamp() - time
}

@objc
public enum GameSpeed: Int {
    case slow
    case normal
    case fast
}

@objc
public enum GLESVersion: Int {
    case gles1
    case gles2
    case gles3
    case gles3_1

	#if canImport(OpenGLES)
    public var eaglRenderingAPI: EAGLRenderingAPI {
        switch self {
        case .gles1: return .openGLES1
        case .gles2: return .openGLES2
        case .gles3, .gles3_1: return .openGLES3
        }
    }
	#endif
}

@objc
public enum PVEmulatorCoreErrorCode: Int, Error {
    case couldNotStart            = -1
    case couldNotLoadRom          = -2
    case couldNotLoadState        = -3
    case stateHasWrongSize        = -4
    case couldNotSaveState        = -5
    case doesNotSupportSaveStates = -6
    case missingM3U               = -7
}

@objc
public protocol PVAudioDelegate: AnyObject {
    func audioSampleRateDidChange()
}

@objc
public protocol PVRenderDelegate: AnyObject {
    func startRenderingOnAlternateThread()
    func didRenderFrameOnAlternateThread()
}

@objc
public protocol EmulatorAudioDelegate: AnyObject {
    func emulatorAudioSampleRateChanged(_ samplerate: Double)
}

@available(iOS 14.0, tvOS 14.0, *)
private var hapticEngines: [CHHapticEngine?] = [CHHapticEngine?].init(repeating: nil, count: 4)

@objc
public protocol CoreInterface: NSObjectProtocol {
    
    var gameInterval: TimeInterval { get }
    var frameInterval: TimeInterval { get }
    
    var shouldStop: Bool { get }
    
    var audioDelegate: PVAudioDelegate? { get set }
    var renderDelegate: PVRenderDelegate? { get set }
    
    // MARK: Video
    var emulationFPS: Double { get }
    var renderFPS: Double { get }
    
    // MARK: Audio
    //    var sampleRate: Double { get }
    var ringBuffers: [RingBuffer] { get }
    // MARK:
    // MARK:
    
    var isRunning: Bool { get }
    var romName: String? { get }
    var saveStatesPath: String? { get }
    var batterySavesPath: String? { get }
    //    var BIOSPath: String? { get } // How to force objc to be uppcase?
    var systemIdentifier: String? { get }
    var coreIdentifier: String? { get }
    var romMD5: String? { get }
    var romSerial: String? { get }
    var supportsSaveStates: Bool { get }
    var supportsRumble: Bool { get }
    
    // atomic
    var shouldResyncTime: Bool { get set }
    
    var gameSpeed: GameSpeed { get }
    var isSpeedModified: Bool { get }
    
    var controller1: GCController? { get }
    var controller2: GCController? { get }
    var controller3: GCController? { get }
    var controller4: GCController? { get }
    
    var emulationLoopThreadLock: NSLock { get }
    var frontBufferCondition: NSCondition { get }
    var frontBufferLock: NSLock { get }
    var isFrontBufferReady: Bool { get }
    var glesVersion: GLESVersion { get }
	#if canImport(OpenGLES)
    var glesShareGroup: EAGLSharegroup? { get set }
	#endif
    var depthFormat: GLenum { get }
    
    var screenRect: CGRect { get }
    var aspectSize: CGSize { get }
    var bufferSize: CGSize { get }
    var isDoubleBuffered: Bool { get }
    var rendersToOpenGL: Bool { get }
    var pixelFormat: GLenum { get }
    var pixelType: GLenum { get }
    var internalPixelFormat: GLenum { get }
    //    var audioSampleRate: Double { get set }
    var channelCount: Int { get }
    var audioBufferCount: Int { get }
    var audioBitDepth: Int { get }
    var isEmulationPaused: Bool { get }
    //    var videoBuffer: UnsafeMutablePointer<UInt16>? { get }
    //
    // NS_REQUIRES_SUPER
    func startEmulation()
    func resetEmulation()
    // NS_REQUIRES_SUPER
    func setPauseEmulation(_: Bool)
    // NS_REQUIRES_SUPER
    func stopEmulation()
    func executeFrame()
    
    func loadFile(atPath path: String) throws
    
    func updateControllers()
    func swapBuffers()
    
    //    // DEPRECATED_MSG_ATTRIBUTE("Use saveStateToFileAtPath:completionHandler: instead."
    //    func saveStateToFile(atPath path: String) throws
    //    // DEPRECATED_MSG_ATTRIBUTE("Use loadStateFromFileAtPath:completionHandler: instead."
    //    func loadStateToFile(atPath path: String) throws
    //
    ////    @nonobjc func saveStateToFile(atPath path: String, completionHandler block: SaveStateCompletion)
    ////    @nonobjc func loadStateToFile(atPath path: String, completionHandler block: SaveStateCompletion)
    //
    // MARK: - Audio
#if !os(tvOS) && !os(macOS)
    func setPreferredSampleRate(_: Double) throws
#endif
    
    func getAudioBuffer(_ buffer: UnsafeMutableRawPointer, frameCount: UInt32, bufferIndex: UInt)
    
    func channelCount(forBuffer buffer: Int) -> Int
    func audioBufferSize(forBuffer buffer: Int) -> Int
    func audioSampleRate(forBuffer buffer: Int) -> Double
    func setAudioEnabled(_ enabled: Bool)
    @objc(ringBufferAtIndex:)
    func ringBuffer(at index: Int) -> RingBuffer
}
//

#if canImport(OpenGLES)
import OpenGLES.ES3
#endif
#if canImport(OpenGL)
import OpenGL
#endif

#if os(tvOS)
fileprivate let HAS_HAPTICS = false
#elseif os(iOS)
fileprivate let HAS_HAPTICS = true
#else
fileprivate let HAS_HAPTICS = false
#endif
// TODO: FrameInterval should be called, frameRate everywhere since we use fps, not 1/fps
fileprivate let defaultFrameInterval: TimeInterval = 60.0  //1.0 / 60.0


// Used to normalize mach clock ticks to nanosec
fileprivate var timebase_ratio: Double = 0

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

@objcMembers
@objc open class PVEmulatorCore: NSObject, CoreInterface {
#if canImport(OpenGLES)
	public var glesShareGroup: EAGLSharegroup? = {
		let sg = EAGLSharegroup.init()
		sg.debugLabel = "EMU-Core Group"
		return sg
	}()
#endif
    
    static private let initialized: Bool = {
        if timebase_ratio == 0 {
            var timebase_info: mach_timebase_info_data_t = mach_timebase_info()
            mach_timebase_info(&timebase_info)
            timebase_ratio = Double(timebase_info.numer) / Double(timebase_info.denom)
        }
        return true
    }()
    
    // MARK: Internal Properties
    internal var framerateMultiplier: Double = 1.0 {
        didSet {
            if framerateMultiplier != oldValue {
                gameInterval = 1.0 / (framerateMultiplier * frameInterval)
            }
        }
    }
    
    public fileprivate(set) var ringBuffers: [RingBuffer] = {
        var a = [RingBuffer]()
        a.reserveCapacity(3)
        return a
    }()
    
    #if os(iOS)
    public fileprivate(set) var rumbleGenerator: UIImpactFeedbackGenerator? // TODO: Don't use UIImpactFeedbackGenerator
    #endif
    // MARK: - Public Properties
    public fileprivate(set) var gameInterval: TimeInterval = 60.0 // TODO: 1 / 60.0
    public fileprivate(set) var frameInterval: TimeInterval = 60.0 // TODO: 1 / 60.0
    
    
    public fileprivate(set) var emulationFPS: Double = 60.0
    public fileprivate(set) var renderFPS: Double = 60.0
    //    public var shouldResyncTime: Bool = false
    //    public var isSpeedModified: Bool = false
    public var gameSpeed: GameSpeed = .normal {
        didSet {
            if gameSpeed != oldValue {
                switch gameSpeed {
                case .slow: framerateMultiplier = 0.2
                case .normal: framerateMultiplier = 1.0
                case .fast: framerateMultiplier = 0.2
                }
            }
        }
    }
    public var isRunning: Bool = false
//    @NSCopying
    public var romName: String?
//    @NSCopying
    public var saveStatesPath: String?
//    @NSCopying
    public var batterySavesPath: String?
//    @NSCopying
    public var BIOSPath: String?
//    @NSCopying
    public var systemIdentifier: String?
//    @NSCopying
    public var coreIdentifier: String?
//    @NSCopying
    public var romMD5: String?
//    @NSCopying
    public var romSerial: String?
    public var supportsSaveStates: Bool = false
    public var supportsRumble: Bool = false
    public var shouldStop: Bool = false
    public var audioDelegate: PVAudioDelegate?
    public var renderDelegate: PVRenderDelegate?
    public fileprivate(set) var emulationLoopThreadLock: NSLock = NSLock()
    public fileprivate(set) var frontBufferCondition: NSCondition = NSCondition()
    public fileprivate(set) var frontBufferLock: NSLock = NSLock()
    public var isFrontBufferReady: Bool = false
    public var glesVersion: GLESVersion = .gles3
    public var depthFormat: GLenum = GLenum(GL_DEPTH_COMPONENT)
    public var screenRect: CGRect = CGRect.zero
    public var aspectSize: CGSize = CGSize.zero
    public var bufferSize: CGSize = CGSize.zero
    public var isDoubleBuffered: Bool = false
    public var rendersToOpenGL: Bool = false
    public var pixelFormat: GLenum = GLenum(GL_RGBA)
    public var pixelType: GLenum = GLenum(GL_UNSIGNED_BYTE)
    public var internalPixelFormat: GLenum = GLenum(GL_RGBA)
    public var audioBufferCount: Int = 0
    public var audioBitDepth: Int = 0
    public var isEmulationPaused: Bool = false
    public var videoBuffer: UnsafeMutablePointer<UInt16>? = nil
    public var controller1: GCController? = nil {
        didSet {
            //            if let controller = controller1 {
            //                controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, _ in
            //                    // TODO: Use callbacks instead of plling?
            //                    self?.handleGamepad(gamepad)
            //                }
            //            }
            
            if supportsRumble {
                if let controller = controller1, !controller.isAttachedToDevice {
                    stopHaptic()
                    // Saves battery power by stopping rumble when the controller is not connected
                } else {
                    startHaptic()
                }
            }
        }
    }
    public var controller2: GCController? = nil
    public var controller3: GCController? = nil
    public var controller4: GCController? = nil
    
    public var controllers: [GCController] {
        return [controller1, controller2, controller3, controller4].compactMap { $0 }
    }
    
    public fileprivate(set) var audioBuffers: [UnsafeMutablePointer<UInt16>] = .init()
    fileprivate lazy var isDoubleBufferedCached: Bool = { isDoubleBuffered }()
    //  MARK: - Initialization
    
    override init() {
        super.init()
        let count = audioBufferCount
        for i in 0..<count {
            let buffer = UnsafeMutablePointer<UInt16>.allocate(
                capacity: Int(audioBufferSize(forBuffer: Int(i))))
            audioBuffers.append(buffer)
        }
        emulationLoopThreadLock = NSLock()
        frontBufferCondition = NSCondition()
        frontBufferLock = NSLock()
        isFrontBufferReady = false
        gameSpeed = .normal
        isDoubleBufferedCached = isDoubleBuffered
    }
    
    deinit {
        stopEmulation()
        for buffer in audioBuffers {
            buffer.deallocate()
        }
    }
    
    func createError(message: String) -> Error {
        return NSError(
            domain: NSErrorDomain.CoreInterfaceErrorDomain,
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                NSLocalizedFailureReasonErrorKey: "Core does not implement this method.",
                NSLocalizedRecoverySuggestionErrorKey: "Please contact the developer.",
            ])
    }
    
    // MARK: - Execution Loop
    
    // TODO: Make this a throw
    public func startEmulation() {
        guard !isRunning else {
            ELOG("Core is already running")
            return
        }
        if HAS_HAPTICS {
            startHaptic()
        }
        
#if !os(tvOS) && !os(macOS)
        do {
            try setPreferredSampleRate(audioSampleRate)
        } catch {
            ELOG("Error setting preferred sample rate: \(error)")
        }
#endif
//
//        do {
//            EAGLContext.init(api: glesVersion.eaglRenderingAPI, sharegroup: shareGroup)
//            try GLContext.sharedContext.makeCurrent()
//        } catch {
//            ELOG("Error making GL context current: \(error)")
//        }
        
        isRunning = true
        shouldStop = false
        gameSpeed = .normal

		#if !os(macOS) && !os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(channelCount))
        } catch {
            ELOG("Error setting preferred output number of channels: \(error)")
        }
		#endif
        
        emulationLoopThreadLock.lock()
//        let threadAttributes = [
//            .detachNewThreadOnExit,
//            .initially suspended,
//        ] as [NSThread.Attributes]
//        let threadError = NSErrorPointer()
//        let thread = NSThread(
//            target: self, selector: #selector(PVEmulatorCore.emulationLoop), object: nil,
//            attributes: threadAttributes, error: threadError)
//        if let error = threadError?.pointee {
//            ELOG("Error creating emulation loop thread: \(error)")
//            emulationLoopThreadLock.unlock()
//            return
//        }
//        emulationLoopThread = thread
//        thread.start()
        let newThread = Thread(target: self, selector: #selector(PVEmulatorCore.emulationLoop), object: nil)
        newThread.qualityOfService = .userInteractive
        emulationLoopThread = newThread
        newThread.start()
    }
    
    public fileprivate(set) var emulationLoopThread: Thread?
    
    public func stopEmulation() {
        guard isRunning else {
            ELOG("Core is not running")
            return
        }
        if HAS_HAPTICS {
            stopHaptic()
        }
        shouldStop = true
        emulationLoopThreadLock.unlock()
        emulationLoopThread = nil
        isRunning = false
    }
    
    @objc func emulationLoop() {
        // For FPS computation
        var frameCount = 0
        var framesSkipped = 0
        var fpsCounter = PVTimestamp()
        // let fpsCounter = FPSCounter()
        // let fpsCounterRender = FPSCounter()
        // let fpsCounterEmulation = FPSCounter()
        // let fpsCounterAudio = FPSCounter()
        // let fpsCounterInput = FPSCounter()
        // let fpsCounterVideo = FPSCounter()
        // let fpsCounterCore = FPSCounter()
        // let fpsCounterSync = FPSCounter()
        // let fpsCounterSleep = FPSCounter()
        // let fpsCounterTotal = FPSCounter()
        // let fpsCounterAverage = FPSCounter()
        // let fpsCounterAverageRender = FPSCounter()
        // let fpsCounterAverageEmulation = FPSCounter()
        // let fpsCounterAverageAudio = FPSCounter()
        // let fpsCounterAverageInput = FPSCounter()
        // let fpsCounterAverageVideo = FPSCounter()
        // let fpsCounterAverageCore = FPSCounter()
        // let fpsCounterAverageSync = FPSCounter()
        // let fpsCounterAverageSleep = FPSCounter()
        // let fpsCounterAverageTotal = FPSCounter()
        
        //Setup Initial timing
        var origin: TimeInterval = PVTimestamp();
        
        var sleepTime: TimeInterval = 0.0
        var nextEmuTick: TimeInterval = GetSecondsSince(origin)
        
        // var lastFrameTime = CFAbsoluteTimeGetCurrent()
        // var secondsPerFrame = 1.0 / emulationFPS
        
        emulationLoopThreadLock.lock()
        
        // Become real-time thread
        Thread.setThreadPriority(1.0)
        Thread.setRealTimePriority()
        
        // Run emulation loop
        while !shouldStop {
            updateControllers()
            if isRunning {
                executeFrame()
            }
            frameCount += 1
            // if frameCount >= 60 {
            //     frameCount = 0
            //     framesSkipped = 0
            // }
            nextEmuTick += gameInterval
            sleepTime = nextEmuTick - GetSecondsSince(origin)
            if isDoubleBufferedCached {
                let bufferSwapLimit = Date().addingTimeInterval(sleepTime)
                if frontBufferLock.try() || frontBufferLock.lock(before: bufferSwapLimit) {
                    swapBuffers()
                    frontBufferLock.unlock()
                    
                    frontBufferCondition.lock()
                    isFrontBufferReady = true
                    frontBufferCondition.signal()
                    frontBufferCondition.unlock()
                } else {
                    swapBuffers()
                    framesSkipped += 1
                    isFrontBufferReady = true
                }
                sleepTime = nextEmuTick - GetSecondsSince(origin)
            }
            
            if sleepTime > 0.001, !sleepTime.isNaN {
                VLOG("Sleep for \(sleepTime) seconds")
                Thread.sleep(forTimeInterval: sleepTime)
            } else if sleepTime < -0.1 {
                // We're behind, we need to reset emulation time,
                // otherwise emulation will "catch up" to real time
                origin = PVTimestamp()
                nextEmuTick = GetSecondsSince(origin)
                VLOG("Behind emulation time by \(-sleepTime) seconds")
            }
            
            // Compute FPS
            // TODO: Use a proper counter class to calculate
            let timeSinceLastFPS: TimeInterval = GetSecondsSince(fpsCounter)
            if timeSinceLastFPS >= 1.0 {
                emulationFPS = Double(frameCount) / timeSinceLastFPS
                renderFPS = Double(frameCount - framesSkipped) / timeSinceLastFPS
                frameCount = 0
                framesSkipped = 0
                fpsCounter = PVTimestamp()
            }
        }
        emulationLoopThreadLock.unlock()
    }
    
    //   public func resetEmulation() {
    // shouldStop = true
    // emulationLoopThreadLock.lock()
    // emulationLoopThreadLock.unlock()
    // emulationLoopThread.cancel()
    // emulationLoopThread.join()
    // emulationLoopThread = nil
    // shouldStop = false
    // startEmulation()
    //   }
    public func ringBuffer(at index: Int) -> RingBuffer {
        if index >= ringBuffers.count {
            let length: Int = Int(audioBufferSize(forBuffer: index) * 16)
            guard let ringBuffer: RingBuffer = RingBuffer(withLength: length) else {
                fatalError("Failed to create Audio Ring Buffer. Must die.")
            }
            ringBuffers.insert(ringBuffer, at: index)
            return ringBuffer
        } else {
            return ringBuffers[index]
        }
    }
}

@objc
public extension PVEmulatorCore {
	var numberOfUsers: UInt {
        if self.controller4 != nil { return 4 }
        if self.controller3 != nil { return 3 }
        if self.controller2 != nil { return 2 }
        if self.controller1 != nil { return 1 }
        return 1
    }
}

@objc
public extension PVEmulatorCore {

	func rumble() {
        rumble(player: 0)
    }

    @available(iOS 14.0, tvOS 14.0, *)
	func hapticEngine(for player: Int) -> CHHapticEngine? {
        if let engine = hapticEngines[player] {
            return engine
        } else if let controller = controller(for: player),
                  let newEngine = controller.haptics?.createEngine(withLocality: .all)
        {
            hapticEngines[player] = newEngine
            newEngine.isAutoShutdownEnabled = true
            return newEngine
        } else {
            return nil
        }
    }

	func controller(for player: Int) -> GCController? {
        var controller: GCController?
        switch player {
        case 0, 1:
            if let controller1 = self.controller1, controller1.isAttachedToDevice {
#if os(iOS) && !targetEnvironment(macCatalyst)
                rumblePhone()
#else
                VLOG("rumblePhone*(")
#endif
            } else {
                controller = self.controller1
            }
        case 2:
            controller = self.controller2
        case 3:
            controller = self.controller3
        case 4:
            controller = self.controller4
        default:
            WLOG("No player \(player)")
            controller = nil
        }
        return controller
    }
    
    var controller1Snapshot: GCController? { controller1?.capture() }
    var controller2Snapshot: GCController? { controller2?.capture() }
    var controller3Snapshot: GCController? { controller3?.capture() }
    var controller4Snapshot: GCController? { controller4?.capture() }

    // MARK: - Haptic Feedback
    // @available(iOS 14.0, tvOS 14.0, *)
    // public func rumble(player: Int) {
    //     if let engine = hapticEngine(for: player) {
    //         let generator = engine.makeHapticGenerator()
    //         generator.event(
    //             style: .medium,
    //             parameters: [
    //                 .duration: 0.1,
    //                 .intensity: 1.0
    //             ]
    //         )
    //         generator.start(
    //             atTime: nil,
    //             completion: { error in
    //                 if let error = error {
    //                     WLOG("Error generating haptic feedback: \(error)")
    //                 }
    //             }
    //         )
    //     }
    // }

#if os(tvOS) || os(macOS)
    @discardableResult
    func startHaptic() -> Bool {
        return false
        // Do nothing
    }
    func stopHaptic() {
        // Do nothing
    }
    func setPauseEmulation(_ paused: Bool) {
	    self.isRunning = !paused
	}
#else
    @discardableResult
    func startHaptic() -> Bool {
        guard supportsRumble, let controller1 = self.controller1, controller1.isAttachedToDevice  else {
            return false
        }
        //                rumbleGenerator = controller1.makeRumble()
        let rumbleGenerator = UIImpactFeedbackGenerator.init(style: .heavy)
        self.rumbleGenerator = rumbleGenerator
        rumbleGenerator.prepare()
//        rumbleGenerator.play()
        return true
        // TODO: Alt method?
        // if #available(iOS 14.0, tvOS 14.0, *) {
        //     if let engine = hapticEngine(for: 0) {
        //         engine.start()
        //     }
        // }
    }

    func stopHaptic() {
        if Thread.isMainThread {
            DispatchQueue.global().async {
                self.stopHaptic()
            }
        } else {
//            if let rumbleGenerator = self.rumbleGenerator {
//                rumbleGenerator.stop()
//                rumbleGenerator.prepare()
                self.rumbleGenerator = nil
//            }
        }
    }
    
    func setPauseEmulation(_ paused: Bool) {
        self.isRunning = !paused
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if paused {
                self.stopHaptic()
            } else {
                self.startHaptic()
            }
        }
    }
#endif
    
	func rumble(player: Int, sharpness: Float = 0.5, intensity: Float = 1) {
        guard self.supportsRumble else {
            WLOG("Rumble called on core that doesn't support it")
            return
        }
        
        if #available(iOS 14.0, tvOS 14.0, *) {
            if let haptics = hapticEngine(for: player) {
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    ], relativeTime: 0)
                
                do {
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    let player = try haptics.makePlayer(with: pattern)
                    try player.start(atTime: CHHapticTimeImmediate)
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
#if os(iOS) && !targetEnvironment(macCatalyst)
	func rumblePhone() {
        DispatchQueue.main.async { [weak self] in
            self?.rumble(player: 1)
        }
    }
#endif
}

#if canImport(UIKit)
public extension UIDevice {
    fileprivate var modelGeneration: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        
        var modelGeneration: String!
        
        withUnsafePointer(to: &sysinfo.machine) { pointer in
            pointer.withMemoryRebound(
                to: UInt8.self, capacity: Int(Mirror(reflecting: pointer.pointee).children.count),
                { (pointer) in
                    modelGeneration = String(cString: pointer)
                })
        }
        
        return modelGeneration
    }
}
#endif

// MARK: Protocol fullfillments
// ObjC classes don't inherit swift default implimentations,
// so need to copy them again here.
// TODO: Fix the protocols to not be so big and optional
@objc
public extension PVEmulatorCore {
    @objc func setAudioEnabled(_ enabled: Bool) {
        // do nothing
    }
    @objc func channelCount(forBuffer buffer: Int) -> Int {
        return buffer == 0 ? channelCount : 0
    }
#if !os(tvOS) && !os(macOS)
    @objc(setPreferredSampleRate:error:) func setPreferredSampleRate(_ sampleRate: Double) throws {
        let preferredSampleRate = sampleRate > 0 ? sampleRate : AUDIO_SAMPLERATE_DEFAULT
        if preferredSampleRate != currentAVSessionSampleRate {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(preferredSampleRate)
        }
    }
#endif
    @objc func resetEmulation() {
        // do nothing
    }
    @objc func executeFrame() {
        // do nothing
    }
//    @objc(loadFileAtPath:error:)
    @objc(loadFileAtPath:error:) func loadFile(atPath path: String) throws {
        // do nothing
    }
    @objc func updateControllers() {
        // do nothing
    }
    @objc func swapBuffers() {
        // do nothing
        assert(!isDoubleBuffered, "Cores that are double-buffered must implement swapBuffers!")
    }
    @objc var shouldResyncTime: Bool {
        get {
            return false
        }
        set {
            // do nothing
        }
    }
    @objc var isSpeedModified: Bool {
        gameSpeed != .normal
    }
    @objc func getAudioBuffer(_ buffer: UnsafeMutableRawPointer, frameCount: UInt32, bufferIndex: UInt) {
        // do nothing
    }
    @objc func audioSampleRate(forBuffer buffer: Int) -> Double {
        return buffer == 0 ? audioSampleRate : 0
    }
    @objc func audioBufferSize(forBuffer buffer: Int) -> Int {
        let frameSampleCount: Double = audioSampleRate(forBuffer: buffer) / frameInterval
        let channelCount: Int = channelCount(forBuffer: buffer)
        let bytesPerSample: Int = audioBitDepth / 8
        let bytesPerFrame: Int = bytesPerSample * Int(channelCount)
        let bytesPerSecond: Int = bytesPerFrame * Int(frameSampleCount)
        return bytesPerSecond
    }
    @objc var channelCount: Int {
        return 2
    }
}

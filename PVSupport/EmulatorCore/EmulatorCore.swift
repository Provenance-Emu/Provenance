//
//  EmulatorCore.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/20/19.
//  Copyright © 2018 Joseph Mattiello All rights reserved.
//

import Foundation
import GameController
import AVFoundation
import QuartzCore
import UIKit
import OpenGLES

private var defaultFrameInterval: TimeInterval = 60.0
// Different machines have different mach_absolute_time to ms ratios
// calculate this on init
private var timebase_ratio: Double = {
    var s_timebase_info = mach_timebase_info_data_t()
    mach_timebase_info(&s_timebase_info)

    return Double(Double(s_timebase_info.numer) / Double(s_timebase_info.denom))
}()

func GetSecondsSince(_ x: CFTimeInterval) -> CFTimeInterval {
    return CACurrentMediaTime() - x
}

@objc
public enum EmulatorCoreErrorCode : Int, Error {
    case couldNotStart
    case couldNotLoadRom
    case couldNotLoadSaveState
    case stateHasWrongSize
    case couldNotSaveState
    case doesNotSupportSaveStates
    case missingM3U
    case doesNotImplimentSelector
}

@objc
public protocol PVAudioDelegate: class {
    func audioSampleRateDidChange()
}

@objc
public protocol PVRenderDelegate: class {
    func startRenderingOnAlternateThread()
    func didRenderFrameOnAlternateThread()
}

// MARK: -
public typealias SaveStateCompletion = (Bool, Error?) -> Void

//public let EmulatorCoreErrorCodeDomain = "com.provenance-emu.EmulatorCore.ErrorDomain"
/*!
 * @function GET_CURRENT_OR_RETURN
 * @abstract Fetch the current game core, or fail with given return code if there is none.
 */

@objc
public enum GameSpeed : Int, CaseIterable {
    case quarter
    case half
    case normal
    case double
    case quadruple

    public var multiplierSpeed: Float {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.5
        case .normal: return 1.0
        case .double: return 2.0
        case .quadruple: return 4.0
        }
    }

    public var description: String {
        switch self {
        case .quarter: return "Quarter"
        case .half: return "Half"
        case .normal: return "Normal"
        case .double: return "Double"
        case .quadruple: return "Quadruple"
        }
    }
}

@objc
public enum GLESVersion : Int {
    case glesVersion1
    case glesVersion2
    case glesVersion3
}

@objc
public protocol DoubleBufferedCore : EmulatorCore {
    func swapBuffers()
}

@objc
public protocol SaveStateCore : EmulatorCore {
    func saveStateToFile(atPath path: String) throws
    func loadStateFromFile(atPath path: String) throws
}

public extension SaveStateCore {
    public var supportsSaveStates: Bool { return true }
}

@objc
public protocol AsyncSaveStateCore : SaveStateCore {
    func saveStateToFile(atPath path: String?, completion: @escaping (Bool, Error?) -> Void)
    func loadStateFromFile(atPath path: String?, completion: @escaping (Bool, Error?) -> Void)
}

public
extension AsyncSaveStateCore {
    func saveStateToFile(atPath path: String, completion: @escaping (Error?) -> Void) {
        do {
            try saveStateToFile(atPath: path)
            completion(nil)
        } catch {
            completion(error)
        }
    }

    func loadStateFromFile(atPath path: String, completion: @escaping (Error?) -> Void) {
        do {
            try loadStateFromFile(atPath: path)
            completion(nil)
        } catch {
            completion(error)
        }
    }

    public var supportsAsyncSaveStates: Bool { return true }
}

@objc
public protocol RumbleCore : EmulatorCore {
    #if os(iOS)
    func rumble()
    #endif
}

@objc
public protocol GLCore : EmulatorCore { }

public extension GLCore {
    public var rendersToOpenGL: Bool {
        return true
    }
}

@objc
public protocol MultidiscCore : EmulatorCore {
    var discCount: UInt {get}
}

//extension MultidiscCore {
//    var discCount: UInt { }
//}

#if os(iOS)
@available(iOS 10.0, *)
private var rumbleGenerator: UIImpactFeedbackGenerator?
#endif

public
extension RumbleCore {
    #if os(iOS)
    public func rumble() {
        assert(supportsRumble)

        // Don't rumble if using a controller and it's not an attached type.
        guard controller1 == nil || !controller1!.isAttachedToDevice else {
            return
        }

        if #available(iOS 10, *) {
            guard let deviceHasHaptic = UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Bool, deviceHasHaptic, let rumbleGenerator = rumbleGenerator else {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                return
            }

            DispatchQueue.main.async(execute: {
                rumbleGenerator.impactOccurred()
            })
        } else {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    public var supportsRumble: Bool {
        return true
    }

    public func startHaptic() {
        assert(Thread.isMainThread)

        guard controller1 == nil && !controller1!.isAttachedToDevice else {
            ILOG("Not starting rumble since has controller and is not attached device")
            return
        }

        if #available(iOS 10.0, *) {
            if rumbleGenerator == nil {
                rumbleGenerator = UIImpactFeedbackGenerator(style: .heavy)
            }
            rumbleGenerator?.prepare()
        } else {
            // Fallback on earlier versions
        }
    }

    public func stopHaptic() {
        if #available(iOS 10.0, *) {
            if !Thread.isMainThread {
                DispatchQueue.main.async(execute: {
                    self.stopHaptic()
                })
                return
            }
            rumbleGenerator = nil
        } else {
            return
        }
    }
    #else
    public func rumble() { }
    public var supportsRumble: Bool { return false }
    public func startHaptic() { }
    public func stopHaptic() { }
    #endif
}

@objc
public protocol EmulatorCore: NSObjectProtocol, ResponderClient {

    @objc var ringBuffers: [Int:OERingBuffer] {get set}

    @objc var gameInterval: TimeInterval {get}
    @objc var shouldStop:Bool {get set}

    @objc var emulationFPS: Double {get set}
    @objc var renderFPS: Double {get set}
    @objc weak var audioDelegate: PVAudioDelegate? {get set}
    @objc weak var renderDelegate: PVRenderDelegate? {get set}
    @objc var isRunning: Bool {get set}
    @objc var romName: String? {get set}
    @objc var saveStatesPath: String? {get set}
    @objc var batterySavesPath: String? {get set}
    @objc var biosPath: String? {get set}
    @objc var systemIdentifier: String? {get set}
    @objc var coreIdentifier: String? {get set}
    @objc var romMD5: String? {get set}
    @objc var romSerial: String? {get set}
    @objc var shouldResyncTime: Bool {get set}
    @objc var gameSpeed: GameSpeed {get set}
    @objc var isSpeedModified: Bool {get}
    @objc var controller1: GCController? {get set}
    @objc var controller2: GCController? {get set}
    @objc var controller3: GCController? {get set}
    @objc var controller4: GCController? {get set}
    @objc var emulationLoopThreadLock: NSLock {get}
    @objc var frontBufferCondition: NSCondition {get}
    @objc var frontBufferLock: NSLock {get}
    @objc var lockQueue : DispatchQueue {get}

    @objc var isFrontBufferReady: Bool {get set}
    @objc var glesVersion: GLESVersion {get set}
    @objc var depthFormat: GLenum {get}
    @objc var screenRect: CGRect {get}
    @objc var aspectSize: CGSize {get}
    @objc var bufferSize: CGSize {get}
    @objc var pixelFormat: GLenum {get}
    @objc var pixelType: GLenum {get}
    @objc var internalPixelFormat: GLenum {get}
    @objc var frameInterval: TimeInterval {get}
    @objc var audioSampleRate: Double {get}
    @objc var channelCount: AVAudioChannelCount {get}
    @objc var audioBufferCount: UInt {get}
    @objc var audioBitDepth: UInt {get}
    @objc var videoBuffer: UnsafeRawPointer? {get}

    @objc var framerateMultiplier: Float {get}

    // GameCores that render direct to OpenGL rather than a buffer should override this and return YES
    // If the GameCore subclass returns YES, the renderDelegate will set the appropriate GL Context
    // So the GameCore subclass can just draw to OpenGL
    @objc var rendersToOpenGL: Bool {get}
    @objc var supportsSaveStates: Bool {get}
    @objc var supportsAsyncSaveStates: Bool {get}
    @objc var supportsRumble: Bool {get}
    @objc var isDoubleBuffered: Bool {get}

    // MARK: - Audio
    @objc func audioBufferSize(forBuffer buffer: UInt) -> UInt
    @objc func audioSampleRate(forBuffer buffer: UInt) -> Double
    @objc(ringBufferAtIndex:)
    func ringBuffer(at index: Int) -> OERingBuffer

    // MARK: - Execution
    @objc func startEmulation()
    @objc func resetEmulation()

    @objc func setPauseEmulation(_ flag: Bool)
    @objc var isEmulationPaused: Bool {get}
    @objc func stopEmulation()

    @objc func updateControllers()
    @objc func emulationLoopThread()

    #if os(iOS)
    @objc func getSampleRate() -> Float64
    @objc func setPreferredSampleRate(_ sampleRate: Double) throws
    #endif

    @objc func executeFrame()
    @objc func loadFile(atPath path: String) throws
    @objc func channelCount(forBuffer buffer: UInt) -> AVAudioChannelCount
}

public extension EmulatorCore {
    public var audoiSampleRate: Double { return 44100 }
    public var audioBufferCount: UInt { return 1 }
    public var audioBitDepth: UInt { return 16 }

    // MARK: - Audio
    public func audioBufferSize(forBuffer buffer: UInt) -> UInt {
        // 4 frames is a complete guess
        let frameSampleCount : UInt = UInt(ceil(audioSampleRate(forBuffer: buffer) / Double(frameInterval)))
        let channelCount = self.channelCount(forBuffer: buffer)
        let bytesPerSample: UInt = audioBitDepth / 8
        assert(frameSampleCount != 0, "frameSampleCount is 0")
        return UInt(channelCount) * bytesPerSample * frameSampleCount
    }

    public func audioSampleRate(forBuffer buffer: UInt) -> Double {
        guard buffer == 0 else {
            fatalError("Buffer count is greater than 1, must implement audioSampleRate(forBuffer:)")
        }

        return audioSampleRate
    }

    public func ringBuffer(at index: Int) -> OERingBuffer {
        guard let buffer = ringBuffers[index] else {
            let length = audioBufferSize(forBuffer: UInt(index)) * 16
            let newBuffer = OERingBuffer(length: length)!
            ringBuffers[index] = newBuffer
            return newBuffer
        }

        return buffer
    }

    // MARK: - Execution
    public func startEmulation() {
        if !isRunning {
            #if os(iOS)
            if let haptic = self as? RumbleCore {
                haptic.startHaptic()
            }
            do {
                try setPreferredSampleRate(audioSampleRate)
            } catch {
                ELOG("Error setting samplerate: \(error)")
            }
            #endif
            isRunning = true
            shouldStop = false
            gameSpeed = .normal
            Thread.detachNewThreadSelector(#selector(Self.emulationLoopThread), toTarget: self, with: nil)
        }
    }

    public  func resetEmulation() {
        fatalError("Does not impliment selector \(#function)")
    }

    public  func setPauseEmulation(_ flag: Bool) {
        if flag {
            if let rumbling = self as? RumbleCore {
                rumbling.stopHaptic()
            }
            isRunning = false
        } else {
            if let rumbling = self as? RumbleCore {
                rumbling.startHaptic()
            }
            isRunning = true
        }
    }

    public var isEmulationPaused: Bool {
        return !isRunning
    }

    public func stopEmulation() {
        if let rumbling = self as? RumbleCore {
            rumbling.stopHaptic()
        }
        shouldStop = true
        isRunning = false

        isFrontBufferReady = false
        frontBufferCondition.signal()

        //    [self.emulationLoopThreadLock lock]; // make sure emulator loop has ended
        //    [self.emulationLoopThreadLock unlock];
    }

    public func updateControllers() {
        //subclasses may implement for polling
    }

    public func emulationLoopThread() {

        // For FPS computation
        var frameCount: Int = 0
        var framesTorn: Int = 0

        var fpsCounter = CACurrentMediaTime()

        //Setup Initial timing
        var origin = CACurrentMediaTime()

        var sleepTime: TimeInterval = 0
        var nextEmuTick = GetSecondsSince(origin)

        emulationLoopThreadLock.lock()

        //Become a real-time thread:
        MakeCurrentThreadRealTime()

        //Emulation loop
        while !shouldStop {
            updateControllers()

            lockQueue.sync {
                if isRunning {
                    if isSpeedModified {
                        executeFrame()
                    } else {
                        lockQueue.sync {
                            executeFrame()
                        }
                    }
                }
            }
            frameCount += 1

            nextEmuTick += gameInterval
            sleepTime = nextEmuTick - GetSecondsSince(origin)

            if isDoubleBuffered {
                let doubleBufferedSelf = self as! DoubleBufferedCore
                let bufferSwapLimit = Date().addingTimeInterval(sleepTime)
                if frontBufferLock.try() || frontBufferLock.lock(before: bufferSwapLimit) {
                    doubleBufferedSelf.swapBuffers()
                    frontBufferLock.unlock()

                    frontBufferCondition.lock()
                    isFrontBufferReady = true
                    frontBufferCondition.signal()
                    frontBufferCondition.unlock()
                } else {
                    doubleBufferedSelf.swapBuffers()
                    framesTorn += 1

                    isFrontBufferReady = true
                }

                sleepTime = nextEmuTick - GetSecondsSince(origin)
            }

            if sleepTime >= 0 {
                //#if !defined(DEBUG)
                Thread.sleep(forTimeInterval: sleepTime)
                //#endif
            } else if sleepTime < -0.1 {
                // We're behind, we need to reset emulation time,
                // otherwise emulation will "catch up" to real time
                origin = CACurrentMediaTime()
                nextEmuTick = GetSecondsSince(origin)
            }

            // Compute FPS
            let timeSinceLastFPS = GetSecondsSince(fpsCounter)
            if timeSinceLastFPS >= 0.5 {
                emulationFPS = Double(frameCount) / timeSinceLastFPS
                renderFPS = Double(frameCount - framesTorn) / timeSinceLastFPS
                frameCount = 0
                framesTorn = 0
                fpsCounter = CACurrentMediaTime()
            }
        }

        emulationLoopThreadLock.unlock()
    }

    #if os(iOS)
    public func getSampleRate() -> Float64 {
        return AVAudioSession.sharedInstance().sampleRate
    }

    public func setPreferredSampleRate(_ sampleRate: Double = 48000) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setPreferredSampleRate(sampleRate)
        ILOG("session.sampleRate = \(session.sampleRate)")
    }
    #endif

    public var gameInterval: TimeInterval {
        return 1.0 / (frameInterval * Double(framerateMultiplier))
    }

}

@objc
@objcMembers
open class PVEmulatorCore: NSObject, EmulatorCore {
//@objc
//extension PVEmulatorCore: EmulatorCore {

    @objc open lazy var ringBuffers: [Int:OERingBuffer] = {
        (0..<Int(channelCount)).reduce([Int:OERingBuffer](), { (result, index) -> [Int:OERingBuffer] in
            var result = result
            if result[index] == nil {
                result[index] = OERingBuffer(length: audioBufferSize(forBuffer: UInt(index)) * 16)!
            }
            return result
        })
    }()

    @objc open var shouldStop = false
    @objc open var emulationFPS: Double = 0.0
    @objc open var renderFPS: Double = 0.0
    @objc open weak var audioDelegate: PVAudioDelegate?
    @objc open weak var renderDelegate: PVRenderDelegate?
    @objc open public(set) var isRunning = false
    @objc open var romName: String?
    @objc open var saveStatesPath: String?
    @objc open var batterySavesPath: String?
    @objc open var biosPath: String?
    @objc open var systemIdentifier: String?
    @objc open var coreIdentifier: String?
    @objc open var romMD5: String?
    @objc open var romSerial: String?
    @objc open var shouldResyncTime = false
    @objc open var gameSpeed: GameSpeed = .normal
    @objc open var controller1: GCController? = nil {
        didSet {
            if let rumbleCore = self as? RumbleCore {
                if let controller1 = controller1, !controller1.isAttachedToDevice {
                    // Eats battery to have it running if we don't need it
                    rumbleCore.stopHaptic()
                } else {
                    rumbleCore.startHaptic()
                }
            }
        }
    }

    @objc open var controller2: GCController?
    @objc open var controller3: GCController?
    @objc open var controller4: GCController?
    @objc public let emulationLoopThreadLock = NSLock()
    @objc public let frontBufferCondition = NSCondition()
    @objc public let frontBufferLock = NSLock()
    @objc public let lockQueue = DispatchQueue(label: "self")

    @objc open var isFrontBufferReady = false
    @objc open var glesVersion: GLESVersion = .glesVersion3

    @objc
    public override init() {
        super.init()
    }

    @objc
    deinit {
        stopEmulation()
    }

    @objc open var isSpeedModified: Bool { return gameSpeed != .normal }

    @objc open var depthFormat: GLenum {
        doesNotImplementSelector(#function)
    }
    @objc open var screenRect: CGRect {
        doesNotImplementSelector(#function)
    }
    @objc open var aspectSize: CGSize {
        doesNotImplementSelector(#function)
    }
    @objc open var bufferSize: CGSize {
        doesNotImplementSelector(#function)
    }
    @objc open var pixelFormat: GLenum {
        doesNotImplementSelector(#function)
    }
    @objc open var pixelType: GLenum {
        doesNotImplementSelector(#function)
    }
    @objc open var internalPixelFormat: GLenum {
        doesNotImplementSelector(#function)
    }
    @objc open var frameInterval: TimeInterval { return defaultFrameInterval }
//    @objc open var audioSampleRate: Double {
//        doesNotImplementSelector(#function)
//    }
    @objc open var channelCount: AVAudioChannelCount {
        doesNotImplementSelector(#function)
    }
    @objc open var videoBuffer: UnsafeRawPointer? {
        doesNotImplementSelector(#function)
    }

    @objc open var framerateMultiplier: Float { return gameSpeed.multiplierSpeed }

    // GameCores that render direct to OpenGL rather than a buffer should override this and return YES
    // If the GameCore subclass returns YES, the renderDelegate will set the appropriate GL Context
    // So the GameCore subclass can just draw to OpenGL
    @objc open var rendersToOpenGL: Bool { return false }
    @objc open var supportsSaveStates: Bool { return false }
    @objc open var supportsAsyncSaveStates: Bool { return false }
    @objc open var supportsRumble: Bool { return self is RumbleCore }
    @objc open var isDoubleBuffered: Bool {
        return self is DoubleBufferedCore
    }

    @objc
    open func executeFrame() {
        doesNotImplementOptionalSelector(#function)
    }

    func doesNotImplementOptionalSelector(_ function: String) -> Never {
        fatalError("doesNotImplementOptionalSelector: \(function)")
    }

    func doesNotImplementSelector(_ function: String) -> Never {
        fatalError("doesNotImplementSelector: \(function)")
    }

    @objc
    open func loadFile(atPath path: String) throws {
        doesNotImplementSelector(#function)
    }

    @objc
    open func channelCount(forBuffer buffer: UInt) -> AVAudioChannelCount {
        if buffer == 0 {
            return channelCount
        }

        ELOG("Buffer counts greater than 1 must implement channelCount(forBuffer:)")
        doesNotImplementSelector(#function)
    }

    // MARK: - Fuck you objc bridge
    open var audioSampleRate: Double { return (self as EmulatorCore).audioSampleRate }
    open var audioBufferCount: UInt { return (self as EmulatorCore).audioBufferCount }
    open var audioBitDepth: UInt { return (self as EmulatorCore).audioBitDepth }
//
    // MARK: - Audio
    @objc open func audioBufferSize(forBuffer buffer: UInt) -> UInt {
        return (self as EmulatorCore).audioBufferSize(forBuffer:buffer)
    }

    @objc open func audioSampleRate(forBuffer buffer: UInt) -> Double {
        return (self as EmulatorCore).audioSampleRate(forBuffer:buffer)
    }

    @objc open func ringBuffer(at index: Int) -> OERingBuffer {
        return (self as EmulatorCore).ringBuffer(at:index)
    }

    // MARK: - Execution
    @objc open func startEmulation() {
        (self as EmulatorCore).startEmulation()
    }

    @objc open func resetEmulation() {
        (self as EmulatorCore).resetEmulation()
    }

    @objc open func setPauseEmulation(_ flag: Bool) {
        return (self as EmulatorCore).setPauseEmulation(flag)
    }

    @objc open var isEmulationPaused: Bool {
        return (self as EmulatorCore).isEmulationPaused
    }

    @objc open func stopEmulation() {
        (self as EmulatorCore).stopEmulation()
    }

    @objc open func updateControllers() {
        (self as EmulatorCore).updateControllers()
    }

    @objc open func emulationLoopThread() {
        (self as EmulatorCore).emulationLoopThread()
    }

    #if os(iOS)
    @objc open func getSampleRate() -> Float64 {
        return (self as EmulatorCore).getSampleRate()
    }

    @objc open func setPreferredSampleRate(_ sampleRate: Double = 48000) throws {
        try (self as EmulatorCore).setPreferredSampleRate(sampleRate)
    }
    #endif

    @objc open var gameInterval: TimeInterval {
        return (self as EmulatorCore).gameInterval
    }
}

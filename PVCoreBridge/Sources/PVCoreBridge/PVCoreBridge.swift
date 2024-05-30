//
//  PVCoreBridge.swift
//
//
//  Created by Joseph Mattiello on 5/18/24.
//

import Foundation
import PVAudio
import GameController
import PVLogging
@_exported import MetalKit

#if canImport(UIKit)
import UIKit
#endif

@objc
public protocol EmulatorCoreAudioDataSource {

    @objc var frameInterval: TimeInterval { get }

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

@objc
public protocol EmulatorCoreControllerDataSource {
    var controller1: GCController? { get }
    var controller2: GCController? { get }
    var controller3: GCController? { get }
    var controller4: GCController? { get }

    var controller5: GCController? { get }
    var controller6: GCController? { get }
    var controller7: GCController? { get }
    var controller8: GCController? { get }

    func controller(forPlayer: UInt) -> GCController?
    #if canImport(UIKit)
    var touchViewController: UIViewController? { get }
    #endif
}

@available(iOS 14.0, tvOS 14.0, *)
private var hapticEngines: [CHHapticEngine?] = [CHHapticEngine?].init(repeating: nil, count: 4)

public extension EmulatorCoreControllerDataSource {

    func controller(for player: Int) -> GCController? {
        switch player {
        case 1:
            if let controller1 = self.controller1, controller1.isAttachedToDevice {
#if os(iOS) && !targetEnvironment(macCatalyst)
                (self as? EmulatorCoreRumbleDataSource)?.rumblePhone()
#else
                VLOG("rumblePhone*(")
#endif
            }
            return controller1
        case 2: return controller2
        case 3: return controller3
        case 4: return controller4
        case 5: return controller5
        case 6: return controller6
        case 7: return controller7
        case 8: return controller7
        default:
            WLOG("No player \(player)")
            return nil
        }
    }
}

@objc
public protocol EmulatorCoreRumbleDataSource: EmulatorCoreControllerDataSource {
    var supportsRumble: Bool { get }
}

#if canImport(CoreHaptics)
import CoreHaptics
public extension EmulatorCoreRumbleDataSource {
    var supportsRumble: Bool { false }

    func rumble() {
        rumble(player: 0)
    }
}
#endif
public extension EmulatorCoreRumbleDataSource {

    @available(iOS 14.0, tvOS 14.0, *)
    func hapticEngine(for player: Int) -> CHHapticEngine? {
        if let engine = hapticEngines[player] {
            return engine
        } else if let controller = controller(for: player), let newEngine = controller.haptics?.createEngine(withLocality: .all) {
            hapticEngines[player] = newEngine
            newEngine.isAutoShutdownEnabled = true
            return newEngine
        } else {
            return nil
        }
    }

    func rumble(player: Int) {
        guard self.supportsRumble else {
            WLOG("Rumble called on core that doesn't support it")
            return
        }

        if #available(iOS 14.0, tvOS 14.0, *) {
            if let haptics = hapticEngine(for: player) {
#warning("deviceHasHaptic incomplete")
                // TODO: haptic vibrate
            }
        } else {
            // Fallback on earlier versions
        }
    }

    func rumblePhone() {
#if os(iOS) && !targetEnvironment(macCatalyst)

        let deviceHasHaptic = (UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int ?? 0) > 0

        DispatchQueue.main.async {
            if deviceHasHaptic {
#warning("deviceHasHaptic incomplete")

                //                AudioServicesStopSystemSound(kSystemSoundID_Vibrate)

                let vibrationLength = 30

                // Must use NSArray/NSDictionary to prevent crash.
                let pattern: [Any] = [false, 0, true, vibrationLength]
                let dictionary: [String: Any] = ["VibePattern": pattern, "Intensity": 1]

                //                AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary as NSDictionary)
                self.rumble()
            }
            //            else {
            //                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            //            }
        }
#endif
    }
}

@objc
public protocol EmulatorCoreSavesDataSource {
    var saveStatesPath: String? { get }
    var batterySavesPath: String? { get }
    var supportsSaveStates: Bool { get }
}

//public extension EmulatorCoreSavesDataSource {
//    public var saveStatesPath: String {
//        #warning("saveStatesPath incomplete")
//        // WARN: Copy from PVEMulatorConfiguration or refactor it here?
//        return ""
//    }
//
//    public var batterySavesPath: String {
//        #warning("batterySavesPath incomplete")
//
//        return ""
//    }

//    public var supportsSaveStates: Bool { true }
//}

@objc public protocol EmulatorCoreSavesSerializer {
    typealias SaveStateCompletion = (Bool, Error?) -> Void

    func saveState(toFileAtPath path: String, error: NSError) -> Bool
    func loadState(toFileAtPath path: String, error: NSError) -> Bool

#warning("Finish this async wrapper")
    func saveState(toFileAtPath fileName: String,
                   completionHandler block: SaveStateCompletion)

    func loadState(fromFileAtPath fileName: String,
                   completionHandler block: SaveStateCompletion)

//    typealias SaveCompletion = (Bool, Error)
//
//    func saveState(toFileAtPath path: String, completionHandler completion: SaveCompletion)
//    func loadState(toFileAtPath path: String, completionHandler completion: SaveCompletion)
}

@objc
public
enum GLESVersion: Int {
    @objc(GLESVersion1)
    case version1
    @objc(GLESVersion2)
    case version2
    @objc(GLESVersion3)
    case version3
}

@objc
public protocol EmulatorCoreVideoDelegate {
    var emulationFPS: Double { get }
    var renderFPS: Double { get }
    var glesVersion: GLESVersion { get }
    var isDoubleBuffered: Bool { get }
    var rendersToOpenGL: Bool { get }
    var pixelFormat: GLenum  { get }
    var pixelType: GLenum  { get }
    var internalPixelFormat: GLenum { get }
    var depthFormat: GLenum  { get }
    var screenRect: CGRect  { get }
    var aspectSize: CGSize  { get }
    var videoBufferSize: CGSize { get }
    var alwaysUseMetal: Bool { get }

    var renderDelegate: PVRenderDelegate? { get set }
}

public extension EmulatorCoreVideoDelegate {
    var emulationFPS: Double { 0.0 }
    var renderFPS: Double { 0.0 }
    var glesVersion: GLESVersion  { .version3 }
    var isDoubleBuffered: Bool { false }
    var rendersToOpenGL: Bool { false }
    var pixelFormat: GLenum  { 0 }
    var pixelType: GLenum {  0 }
    var internalPixelFormat: GLenum  { 0 }
    var depthFormat: GLenum { 0 }
    var screenRect: CGRect { .zero }
    var aspectSize: CGSize { .zero }
    var bufferSize: CGSize { .zero }
    var alwaysUseMetal: Bool { false }
}

// MARK: Delegate Protocols
@objc
public protocol PVRenderDelegate {
    // Required methods
    func startRenderingOnAlternateThread()
    func didRenderFrameOnAlternateThread()

    /*!
     * @property presentationFramebuffer
     * @discussion
     * 2D - Not used.
     * 3D - For cores which can directly render to a GL FBO or equivalent,
     * this will return the FBO which game pixels eventually go to. This
     * allows porting of cores that overwrite GL_DRAW_FRAMEBUFFER.
     */
    var presentationFramebuffer: AnyObject? { get }

    // Optional property
    #if !os(visionOS)
    @objc(optional) var mtlView: MTKView? { get }
    #endif
}

@objc
public protocol PVAudioDelegate {
    func audioSampleRateDidChange();
}

// MARK: - Enums
@objc
public enum GameSpeed: Int {
    case slow, normal, fast
}

@objc
public protocol EmulatorCoreRunLoop {
    var shouldStop: Bool { get }
    var isRunning: Bool { get }
    var shouldResyncTime: Bool { get }
    var skipEmulationLoop: Bool { get }
    var skipLayout: Bool { get }

    var gameSpeed: GameSpeed { get set }
    var emulationLoopThreadLock: NSLock { get }
    var frontBufferCondition: NSCondition { get }
    var frontBufferLock: NSLock { get }
    var isFrontBufferReady: Bool { get }
}

public extension EmulatorCoreRunLoop {
    var shouldStop: Bool { false }
    var isRunning: Bool { false }
    var shouldResyncTime: Bool { true }
    var skipEmulationLoop: Bool { true }
    var skipLayout: Bool { false }

    var gameSpeed: GameSpeed { .normal }
    var isFrontBufferReady: Bool { false }
}

@objc
public protocol EmulatorCoreIOInterface {
    var romName: String? { get }
    var BIOSPath: String? { get }
    var systemIdentifier: String? { get }
    var coreIdentifier: String? { get }
    var romMD5: String? { get }
    var romSerial: String? { get }

    var screenType: String? { get }
}

//
	//  PVEmulatorCore.swift
	//  PVSupport
	//
	//  Created by Joseph Mattiello on 3/8/18.
	//  Copyright © 2018 James Addyman. All rights reserved.
	//

import Foundation
import CoreHaptics

public typealias SaveStateCompletion = () throws -> (Bool)
//
//@objc
//public enum GameSpeed: Int {
//    case slow
//    case normal
//    case fast
//}
//
//@objc
//public enum GameSpeed: GLESVersion {
//    case `1`
//    case `2`
//    case `3`
//}
//
//@objc
//public enum PVEmulatorCoreErrorCode: Error {
//    case couldNotStart            = -1
//    case couldNotLoadRom          = -2
//    case couldNotLoadState        = -3
//    case stateHasWrongSize        = -4
//    case couldNotSaveState        = -5
//    case doesNotSupportSaveStates = -6
//    case missingM3U               = -7
//}
//
//@objc
//public protocol PVAudioDelegate: NSObject {
//    func audioSampleRateDidChange()
//
//}
//
//@objc
//public protocol PVRenderDelegate: NSObject {
//    func startRenderingOnAlternateThread()
//    func didRenderFrameOnAlternateThread()
//}
//
//@objc
//public protocol EmulatorAudioDelegate: NSObject {
//    func emulatorAudioSampleRateChanged(_ samplerate: Double)
//}

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
    var emulationFPS: Double { get set }
    var renderFPS: Double { get set }


    // MARK: Audio
//    var sampleRate: Double { get }

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
    var channelCount: UInt { get }
    var audioBufferCount: UInt { get }
    var audioBitDepth: UInt { get }
    var isEmulationPaused: Bool { get }
//    var videoBuffer: UnsafeMutablePointer<UInt16>? { get }
//
    // NS_REQUIRES_SUPER
    func startEmulation()
    func resetEmulation()
    // NS_REQUIRES_SUPER
    func setPauseEmulation(_ : Bool)
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
    #if !os(tvOS)
    func setPreferredSampleRate(_ : Double) throws
    #endif

    func getAudioBuffer(_ buffer: UnsafeMutableRawPointer, frameCount: UInt32, bufferIndex: UInt)

    func channelCount(forBuffer buffer: UInt) -> UInt
    func audioBufferSize(forBuffer buffer: UInt) -> UInt
    func audioSampleRate(forBuffer buffer: UInt) -> Double
    func setAudioEnabled(_ enabled: Bool)
    @objc(ringBufferAtIndex:)
    func ringBuffer(at index: UInt) -> RingBuffer
 }
//
//@objcMembers
//@objc public class PVEmulatorCore: NSObject {
//
//}

// MARK: Default Implimentation
//public extension CoreInterface {
//    var discCount: UInt { 0 }
//    var audioBitDepth: UInt { 16 }
//    var audioBufferCount: UInt { 1 }
////    var frameInterval: TimeInterval { defaultFrameInterval }
//
//    var depthFormat: GLenum { 0 }
//
//    var supportsSaveStates: Bool { true }
//    var isDoubleBuffered: Bool { false }
//
////    func audioBufferSize(forBuffer buffer: UInt) -> UInt {
////        let frameSampleCount: UInt = self.audioSampleRate(forBuffer: buffer) / self.frameInterval
////        let channelCount: UInt = channelCount(forBuffer: buffer)
////        let bytesPerSample: UInt = audioBitDepth / 8
////        return channelCount * bytesPerSample * frameSampleCount
////    }
//    
//    var isSpeedModified: Bool {  return gameSpeed != .normal }
//}

@objc
extension PVEmulatorCore: CoreInterface {
//    public var supportsRumble: Bool { false }

}

@objc public class PVEmulatorCoreSwift: PVEmulatorCore {
    
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
        } else if let controller = controller(for: player), let newEngine = controller.haptics?.createEngine(withLocality: .all) {
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

    func rumble(player: Int, sharpness: Float = 0.5, intensity: Float = 1) {
		guard self.supportsRumble else {
			WLOG("Rumble called on core that doesn't support it")
			return
		}

        if #available(iOS 14.0, tvOS 14.0, *) {
            if let haptics = hapticEngine(for: player) {
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
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

private extension UIDevice {
	var modelGeneration: String {
		var sysinfo = utsname()
		uname(&sysinfo)

		var modelGeneration: String!

		withUnsafePointer(to: &sysinfo.machine) { pointer in
			pointer.withMemoryRebound(to: UInt8.self, capacity: Int(Mirror(reflecting: pointer.pointee).children.count), { (pointer) in
				modelGeneration = String(cString: pointer)
			})
		}

		return modelGeneration
	}
}

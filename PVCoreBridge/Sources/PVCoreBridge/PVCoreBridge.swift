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
import PVPlists

@_exported import MetalKit

public class PVBundleFinder {
    public static func bundle(forClass: AnyClass) -> Bundle {
        return Bundle(for: forClass)
    }
}

#if canImport(UIKit)
import UIKit
#endif

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
public protocol EmulatorCoreRumbleDataSource: EmulatorCoreControllerDataSource {
    var supportsRumble: Bool { get }
}

public protocol EmulatorCoreInfoProvider {
    var identifier: String { get }
    var principleClass: String { get }

    var supportedSystems: [String] { get }

    var projectName: String { get }
    var projectURL: String { get }
    var projectVersion: String { get }
    var disabled: Bool { get }
    var subCores: [Self]? { get }
}

extension EmulatorCoreInfoPlist: EmulatorCoreInfoProvider { }

extension CorePlistEntry: EmulatorCoreInfoProvider {

    public var identifier: String { PVCoreIdentifier }
    public var principleClass: String { PVPrincipleClass }
    public var supportedSystems: [String] { PVSupportedSystems }
    public var projectName: String { PVProjectName }
    public var projectURL: String { PVProjectURL }
    public var projectVersion: String { PVProjectVersion }
    public var disabled: Bool { PVDisabled ?? false }
    public var subCores: [CorePlistEntry]? { subCores }
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
//    func saveState(toFileAtPath fileName: String,
//                   completionHandler block: SaveStateCompletion)
//
//    func loadState(fromFileAtPath fileName: String,
//                   completionHandler block: SaveStateCompletion)

    func saveState(toFileAtPath fileName: String) async throws -> Bool
    func loadState(fromFileAtPath fileName: String) async throws -> Bool

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

//@objc
//public protocol PVAudioDelegate {
//    func audioSampleRateDidChange();
//}

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

    var screenType: ScreenTypeObjC { get }
    
    func loadFile(atPath path: String) throws
}

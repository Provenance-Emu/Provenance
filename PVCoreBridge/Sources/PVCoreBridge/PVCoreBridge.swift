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

@objc
public protocol EmulatorCoreInfoProvider {
    var identifier: String { get }
    var principleClass: String { get }

    var supportedSystems: [String] { get }

    var projectName: String { get }
    var projectURL: String { get }
    var projectVersion: String { get }
}

@objc
public protocol EmulatorCoreInfoPlistProvider {
    static var corePlist: EmulatorCoreInfoPlist { get }
    static var resourceBundle: Bundle { get }
}

public extension EmulatorCoreInfoPlistProvider {
    var corePlist: EmulatorCoreInfoPlist { Self.corePlist }
    var resourceBundle: Bundle { Self.resourceBundle }
}

public extension EmulatorCoreInfoProvider where Self: EmulatorCoreInfoPlistProvider {
    var identifier: String { Self.corePlist.identifier }
    var principleClass: String { Self.corePlist.principleClass }
    var supportedSystems: [String] { Self.corePlist.supportedSystems }
    var projectName: String { Self.corePlist.projectName }
    var projectURL: String { Self.corePlist.projectURL }
    var projectVersion: String { Self.corePlist.projectVersion }
}

public enum EmulatorCoreInfoPlistError: Error {
    case missingIdentifier
    case missingPrincipleClass
    case missingSupportedSystems
    case missingProjectName
    case missingProjectURL
    case missingProjectVersion

    case couldNotReadPlist
    case couldNotParsePlist
}

@objc
public final class EmulatorCoreInfoPlist: NSObject, EmulatorCoreInfoProvider, Sendable {
    public let identifier: String
    public let principleClass: String

    public let supportedSystems: [String]

    public let projectName: String
    public let projectURL: String
    public let projectVersion: String

    public init(identifier: String, principleClass: String, supportedSystems: [String], projectName: String, projectURL: String, projectVersion: String) {
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems = supportedSystems
        self.projectName = projectName
        self.projectURL = projectURL
        self.projectVersion = projectVersion
    }

    public init?(fromInfoDictionary dict: [String: Any]) {
        /// Identifier
        guard let identifier = dict["PVCoreIdentifier"] as? String else {
            return nil
        }
        self.identifier = identifier

        /// Principle Class
        guard let principleClass = dict["PVPrincipleClass"] as? String else {
            return nil
        }
        self.principleClass = principleClass

        /// Supported systems
        guard let supportedSystems = dict["PVSupportedSystems"] as? [String] else {
            return nil
        }
        self.supportedSystems = supportedSystems

        /// Project name
        guard let projectName = dict["PVProjectName"] as? String else {
            return nil
        }
        self.projectName = projectName

        /// Project URL
        guard let projectURL = dict["PVProjectURL"] as? String else {
            return nil
        }
        self.projectURL = projectURL

        /// Project Version
        guard let projectVersion = dict["PVProjectVersion"] as? String else {
            return nil
        }
        self.projectVersion = identifier
    }

    public convenience init?(fromURL plistPath: URL) throws {
        guard let data = try? Data(contentsOf: plistPath) else {
            ELOG("Could not read Core.plist")
            throw EmulatorCoreInfoPlistError.couldNotReadPlist
        }

        guard let plistObject = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            ELOG("Could not generate parse Core.plist")
            throw EmulatorCoreInfoPlistError.couldNotParsePlist
        }

        self.init(fromInfoDictionary: plistObject)
    }
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
}

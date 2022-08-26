//
//  CoreInterface.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/25/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

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

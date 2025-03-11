//
//  PVEmulatorCore.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
#if canImport(GameController)
import GameController
#endif
import PVLogging
import PVPrimitives

@_exported import PVAudio
@_exported import PVCoreBridge

public typealias OptionalCore = PVEmulatorCore & CoreOptional

/// Base class for all Emulators
@objc
@objcMembers
open class PVEmulatorCore: NSObject, ObjCBridgedCore, PVEmulatorCoreT {

    open var bridge: (any ObjCBridgedCoreBridge)!

    @objc dynamic open var resourceBundle: Bundle { Bundle.module }

    // MARK: EmulatorCoreAudioDataSource

#if canImport(GameController)
    @objc
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
    @objc public convenience init(valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil) {
        self.init()
        self.valueChangedHandler = valueChangedHandler
    }
    // MARK: EmulatorCoreControllerDataSource
    @objc
    dynamic open var controller1: GCController? {
        get { bridge.controller1 }
        set { bridge.controller1 = newValue
            guard let controller1 = controller1, !controller1.isAttachedToDevice else {
                stopHaptic()
                return
            }
            startHaptic()
        }
    }

    @objc dynamic open var controller2: GCController? {
        get { bridge.controller2 }
        set { bridge.controller2 = newValue } }
    @objc dynamic open var controller3: GCController? {
        get { bridge.controller3 }
        set { bridge.controller3 = newValue } }
    @objc dynamic open var controller4: GCController? {
        get { bridge.controller4 }
        set { bridge.controller4 = newValue } }

    @objc dynamic open var controller5: GCController? {
        get { bridge.controller5 }
        set { bridge.controller5 = newValue } }
    @objc dynamic open var controller6: GCController? {
        get { bridge.controller6 }
        set { bridge.controller6 = newValue } }
    @objc dynamic open var controller7: GCController?  {
        get { bridge.controller7 }
        set { bridge.controller7 = newValue } }
    @objc dynamic open var controller8: GCController? {
        get { bridge.controller8 }
        set { bridge.controller8 = newValue } }
#endif

#if !os(macOS) && !os(watchOS)
    @objc open var touchViewController: UIViewController?
    { didSet { bridge.touchViewController = touchViewController} }
//    { get{ bridge.touchViewController } set { bridge.touchViewController = newValue } }
#endif

//    // MARK: EmulatorCoreRumbleDataSource
//    var supportsRumble: Bool { bridge.supportsRumble }

    // MARK: EmulatorCoreSavesDataSource

    @objc dynamic open var batterySavesPath: String? = nil {
        didSet { bridge.batterySavesPath = batterySavesPath }
    }
    @objc dynamic open var saveStatesPath: String? = nil {
        didSet { bridge.saveStatesPath = saveStatesPath }
    }

    @objc dynamic open var supportsSaveStates: Bool { return bridge.supportsSaveStates ?? false }

    // MARK: EmulatorCoreVideoDelegate

#if canImport(OpenGL) || canImport(OpenGLES)
    @objc dynamic open var glesVersion: GLESVersion = .version3
#endif

    // PVRenderDelegate
    @objc open weak var renderDelegate: (any PVCoreBridge.PVRenderDelegate)?
    { get{ bridge.renderDelegate } set { bridge.renderDelegate = newValue } }

    // MARK: EmulatorCoreRunLoop

    /// Should stop
    @objc dynamic open var shouldStop: Bool
    { get { bridge.shouldStop } set { bridge.shouldStop = newValue } }
    @objc dynamic open var isRunning: Bool
    { get { bridge.isRunning } set { bridge.isRunning = newValue } }
    @objc dynamic open var shouldResyncTime: Bool
    { get { bridge.shouldResyncTime } set { bridge.shouldResyncTime = newValue } }
    @objc dynamic open var skipEmulationLoop: Bool
    { get { bridge.skipEmulationLoop } set { bridge.skipEmulationLoop = newValue } }
    @objc dynamic open var skipLayout: Bool
    { get { bridge.skipLayout } set { bridge.skipLayout = newValue } }

    @objc dynamic open var isFrontBufferReady: Bool
    { get { bridge.isFrontBufferReady } set { bridge.isFrontBufferReady = newValue } }

    @objc dynamic open var gameSpeed: PVCoreBridge.GameSpeed = .normal
    { didSet { bridge.gameSpeed = gameSpeed }}

    @objc dynamic open var emulationLoopThreadLock: NSLock
    { get { bridge.emulationLoopThreadLock } set { bridge.emulationLoopThreadLock = newValue } }

    @objc dynamic open var frontBufferCondition: NSCondition
    { get { bridge.frontBufferCondition } set { bridge.frontBufferCondition = newValue } }

    @objc dynamic open var frontBufferLock: NSLock
    { get { bridge.frontBufferLock } set { bridge.frontBufferLock = newValue } }


    // MARK: EmulatorCoreIOInterface
    @objc dynamic open var romName: String?
    { get { bridge.romName } set { bridge.romName = newValue } }

    @objc dynamic open var BIOSPath: String?
    { get { bridge.BIOSPath } set { bridge.BIOSPath = newValue } }

    @objc dynamic open var systemIdentifier: String?
    { get { bridge.systemIdentifier } set { bridge.systemIdentifier = newValue } }

    @objc dynamic open var coreIdentifier: String?
    { get { bridge.coreIdentifier } set { bridge.coreIdentifier = newValue } }

    @objc dynamic open var romMD5: String?
    { get { bridge.romMD5 } set { bridge.romMD5 = newValue } }

    @objc dynamic open var romSerial: String?
    { get { bridge.romSerial } set { bridge.romMD5 = romSerial } }

    @objc dynamic open var discCount: UInt { bridge.discCount }

    @objc dynamic open var screenType: ScreenTypeObjC = .crt

    @objc dynamic open var extractArchive: Bool
    { get { bridge.extractArchive } set { bridge.extractArchive = newValue } }


    // MARK: Audio
    @objc dynamic open var audioDelegate: (any PVAudioDelegate)?
    { get { bridge.audioDelegate } set { bridge.audioDelegate = newValue } }

    // MARK: Class

    @objc open func initialize() {
//        buildRingBuffers()
        /// Fixes a race condition
        bridge.touchViewController = touchViewController
        bridge.initialize()

        frontBufferLock = .init()
        frontBufferCondition = .init()
        emulationLoopThreadLock = .init()
    }

    //    @nonobjc
    //    open func loadFile(atPath path: String) throws -> Bool {
    //        var error: NSError?
    //        let success = loadFile(atPath: path, error: &error)
    //        if !success {
    //            if let error = error {
    //                throw error
    //            }
    //        }
    //        return success
    //    }

    @objc(loadFileAtPath:error:)
    open func loadFile(atPath path: String) throws {
        //        if let bridge = self as? ObjCCoreBridge {
        //            bridge.test()
        //            try bridge.objCLoadFile(atPath: path)
        //        }
        throw EmulationError.coreDoesNotImplimentLoadFile
    }

    @objc
    required public override init() {
        super.init()
    }

//    private func buildRingBuffers() {
//        let audioBufferCount = Int(audioBufferCount)
//        ringBuffers = (0..<audioBufferCount).compactMap {
//            let length: Int = Int(audioBufferSize(forBuffer: UInt($0)))
//            return RingBuffer.init(withLength: length)
//        }
//    }

    // EmulatorCoreAudioDataSource
    @objc dynamic open var ringBuffers: [RingBufferProtocol]?
    { get { bridge.ringBuffers } set { bridge.ringBuffers = newValue }}

    /// Wrapper for isOn state
    @MainActor
    @objc dynamic open var isOn: Bool {
        get {
            EmulationState.shared.isOn
        }
        set {
            Task {
                await EmulationState.shared.setIsOn(newValue)
            }
        }
    }

    /// Wrapper for coreClassName
    @MainActor
    @objc dynamic open var coreClassName: String {
        get {
            EmulationState.shared.coreClassName
        }
        set {
            Task {
                await EmulationState.shared.setCoreClassName(newValue)
            }
        }
    }

    /// Wrapper for systemName
    @MainActor
    @objc dynamic open var systemName: String {
        get {
                EmulationState.shared.systemName
        }
        set {
            Task {
                await EmulationState.shared.setSystemName(newValue)
            }
        }
    }
}

#if !os(macOS) && !os(watchOS)
/// This method is for forwarding touch events to cores that have TouchScreen cotrols,
/// PSP, 3DS, DS etc
@objc
extension PVEmulatorCore : ResponderClient {
    open func sendEvent(_ event: UIEvent?) {
        bridge.sendEvent(event)
    }
}
#endif

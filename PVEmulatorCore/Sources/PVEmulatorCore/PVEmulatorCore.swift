//
//  PVEmulatorCore.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import GameController
import PVLogging

@_exported import PVAudio
@_exported import PVCoreBridge

public typealias OptionalCore = PVEmulatorCore & CoreOptional

public protocol PVEmulatorCoreT: EmulatorCoreRunLoop, EmulatorCoreIOInterface, EmulatorCoreVideoDelegate, EmulatorCoreSavesSerializer, EmulatorCoreAudioDataSource, EmulatorCoreRumbleDataSource, EmulatorCoreControllerDataSource, EmulatorCoreSavesDataSource, EmulatorCoreInfoProvider {

}

@objc
@objcMembers
open class PVEmulatorCore: NSObject, EmulatorCoreIOInterface, EmulatorCoreSavesDataSource {

    @objc
    public static var coreClassName: String = ""

    @objc
    public static var systemName: String = ""

    @objc
    dynamic open var resourceBundle: Bundle { Bundle.module }

    @available(*, deprecated, message: "Why does this need to exist? Only used for macII in PVRetroCore")
    public static var status: [String: Any] = .init()

    // MARK: EmulatorCoreAudioDataSource

    // MARK: EmulatorCoreControllerDataSource
    public var controller1: GCController? = nil 
    {
        didSet {
            guard let controller1 = controller1, !controller1.isAttachedToDevice else {
                stopHaptic()
                return
            }
            startHaptic()
        }
    }
    public var controller2: GCController? = nil
    public var controller3: GCController? = nil
    public var controller4: GCController? = nil

    public var controller5: GCController? = nil
    public var controller6: GCController? = nil
    public var controller7: GCController? = nil
    public var controller8: GCController? = nil

    #if !os(macOS)
    public var touchViewController: UIViewController? = nil
    #endif

    // MARK: EmulatorCoreRumbleDataSource

    // MARK: EmulatorCoreSavesDataSource

    public var batterySavesPath: String? = nil
    public var saveStatesPath: String? = nil

    public var supportsSaveStates: Bool { return false }

    // MARK: EmulatorCoreVideoDelegate

    public var glesVersion: GLESVersion = .version3


    // PVRenderDelegate
    @objc
    open weak var renderDelegate: (any PVCoreBridge.PVRenderDelegate)? = nil

    // MARK: EmulatorCoreRunLoop


    public var shouldStop: Bool = false
    public var isRunning: Bool = false
    public var shouldResyncTime: Bool  = true
    public var skipEmulationLoop: Bool = true
    public var skipLayout: Bool = false

    @available(*, deprecated, message: "What is this even used for?")
    public var isOn: Bool = false

    public var isFrontBufferReady: Bool = false

    public var gameSpeed: PVCoreBridge.GameSpeed = .normal

    public var emulationLoopThreadLock: NSLock = { NSLock() }()
    public var frontBufferCondition: NSCondition = { NSCondition() }()
    public var frontBufferLock: NSLock = { NSLock() }()

    // MARK: EmulatorCoreIOInterfaceEmulatorCoreIOInterface
    public var romName: String? = nil
    public var BIOSPath: String? = nil
    public var systemIdentifier: String? = nil
    public var coreIdentifier: String? = nil
    public var romMD5: String? = nil
    public var romSerial: String? = nil

    public var discCount: UInt { 0 }

    public var screenType: ScreenTypeObjC = .crt

    public var extractArchive: Bool = true

    // MARK: Audio
    @objc
    public var audioDelegate: (any PVAudioDelegate)? = nil


    // MARK: Class

    @objc
    open func initialize() {
        // Do nothing
        // used by subclasses
        // TODO: Use a better method, use by PVRetroCore only atm @JoeMatt 6/2/24
    }

    @nonobjc
    open func loadFile(atPath path: String) throws -> Bool {
        var error: NSError?
        let success = loadFile(atPath: path, error: &error)
        if !success {
            if let error = error {
                throw error
            }
        }
        return success
    }

    @objc(loadFileAtPath:error:)
    open func loadFile(atPath path: String, error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        // method implementation goes here
        return false
    }

    @objc
    required
    public override init() {
        super.init()
        DispatchQueue.main.sync {
            ringBuffers = Array(repeating: RingBuffer.init(withLength: Int(audioBufferSize(forBuffer: 0)))!, count: Int(audioBufferCount))
        }
    }

    // EmulatorCoreAudioDataSource
    public var ringBuffers: [RingBuffer]? = nil
}

#if !os(macOS)
@objc
extension PVEmulatorCore: ResponderClient {
    @objc open func send(event: UIEvent?) {
        #warning("This is empty in the ObjC version too, but why does this exist? @JoeMatt")
    }
}
#endif

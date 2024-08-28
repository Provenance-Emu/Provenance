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

@_exported import PVAudio
@_exported import PVCoreBridge

public typealias OptionalCore = PVEmulatorCore & CoreOptional

@objc
public protocol PVEmulatorCoreT: EmulatorCoreRunLoop, EmulatorCoreIOInterface, EmulatorCoreVideoDelegate, EmulatorCoreSavesSerializer, EmulatorCoreAudioDataSource, EmulatorCoreRumbleDataSource, EmulatorCoreControllerDataSource, EmulatorCoreSavesDataSource {

}

public enum EmulationError: Error, CustomStringConvertible, CustomNSError {
    
    case failedToLoadFile
    case coreDoesNotImplimentLoadFile
    
    public var description: String {
        switch self {
        case .failedToLoadFile: return "Failed to load file"
        case .coreDoesNotImplimentLoadFile: return "Core does not implement loadFile:error: method"
        }
    }

    public var errorUserInfo: [String: Any] {
        return ["description": description]
    }
}

@objc
@objcMembers
open class PVEmulatorCore: NSObject, EmulatorCoreIOInterface, EmulatorCoreSavesDataSource, @unchecked Sendable {

    @objc
    public static var coreClassName: String = ""

    @objc
    public static var systemName: String = ""

    @objc
    dynamic open var resourceBundle: Bundle { Bundle.module }

    @available(*, deprecated, message: "Why does this need to exist? Only used for macII in PVRetroCore")
    public static var status: [String: Any] = .init()

    // MARK: EmulatorCoreAudioDataSource

#if canImport(GameController)
    // MARK: EmulatorCoreControllerDataSource
    @objc
    dynamic open var controller1: GCController? = nil
    {
        didSet {
            guard let controller1 = controller1, !controller1.isAttachedToDevice else {
                stopHaptic()
                return
            }
            startHaptic()
        }
    }
    
    @objc dynamic open var controller2: GCController? = nil
    @objc dynamic open var controller3: GCController? = nil
    @objc dynamic open var controller4: GCController? = nil

    @objc dynamic open var controller5: GCController? = nil
    @objc dynamic open var controller6: GCController? = nil
    @objc dynamic open var controller7: GCController? = nil
    @objc dynamic open var controller8: GCController? = nil
#endif

    #if !os(macOS) && !os(watchOS)
    @objc dynamic open var touchViewController: UIViewController? = nil
    #endif

    // MARK: EmulatorCoreRumbleDataSource

    // MARK: EmulatorCoreSavesDataSource

    @objc dynamic open var batterySavesPath: String? = nil
    @objc dynamic open var saveStatesPath: String? = nil

    @objc dynamic open var supportsSaveStates: Bool { return false }

    // MARK: EmulatorCoreVideoDelegate

#if canImport(OpenGL) || canImport(OpenGLES)
    @objc dynamic open var glesVersion: GLESVersion = .version3
#endif

    // PVRenderDelegate
    @objc open weak var renderDelegate: (any PVCoreBridge.PVRenderDelegate)? = nil

    // MARK: EmulatorCoreRunLoop

    @objc dynamic open var shouldStop: Bool = false
    @objc dynamic open var isRunning: Bool = false
    @objc dynamic open var shouldResyncTime: Bool  = true
    @objc dynamic open var skipEmulationLoop: Bool = true
    @objc dynamic open var skipLayout: Bool = false

    @available(*, deprecated, message: "What is this even used for?")
    @objc dynamic open var isOn: Bool = false

    @objc dynamic open var isFrontBufferReady: Bool = false

    @objc dynamic open var gameSpeed: PVCoreBridge.GameSpeed = .normal

    @objc dynamic open var emulationLoopThreadLock: NSLock = { NSLock() }()
    @objc dynamic open var frontBufferCondition: NSCondition = { NSCondition() }()
    @objc dynamic open var frontBufferLock: NSLock = { NSLock() }()

    // MARK: EmulatorCoreIOInterfaceEmulatorCoreIOInterface
    @objc dynamic open var romName: String? = nil
    @objc dynamic open var BIOSPath: String? = nil
    @objc dynamic open var systemIdentifier: String? = nil
    @objc dynamic open var coreIdentifier: String? = nil
    @objc dynamic open var romMD5: String? = nil
    @objc dynamic open var romSerial: String? = nil

    @objc dynamic open var discCount: UInt { 0 }

    @objc dynamic open var screenType: ScreenTypeObjC = .crt

    @objc dynamic open var extractArchive: Bool = true

    // MARK: Audio
    @objc dynamic open var audioDelegate: (any PVAudioDelegate)? = nil


    // MARK: Class

    @objc open func initialize() {
        // Do nothing
        // used by subclasses
        // TODO: Use a better method, use by PVRetroCore only atm @JoeMatt 6/2/24
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

//    @objc(loadFileAtPath:error:)
//    open func loadFile(atPath path: String) throws {
//        if let bridge = self as? ObjCCoreBridge {
//            bridge.test()
//            try bridge.objCLoadFile(atPath: path)
//        }
//        throw EmulationError.coreDoesNotImplimentLoadFile
//    }

    @objc
    required
    public override init() {
        super.init()
        ringBuffers = Array(repeating: RingBuffer.init(withLength: Int(audioBufferSize(forBuffer: 0)))!, count: Int(audioBufferCount))
    }

    // EmulatorCoreAudioDataSource
    @objc
    dynamic open var ringBuffers: [RingBuffer]? = nil
}

@objc public protocol ObjCCoreBridge where Self: PVEmulatorCore {

    // MARK: Lifecycle
    @objc func loadFile(atPath: String) throws
//    @objc func executeFrameSkippingFrame(skip: Bool)
    @objc func executeFrame()
    @objc func swapBuffers()
    @objc func stopEmulation()
    @objc func resetEmulation()
    
    // MARK: Output
    @objc var screenRect: CGRect { get }
    @objc var videoBuffer: UnsafeMutableRawPointer? { get }
    @objc var frameInterval: TimeInterval { get }
    @objc var rendersToOpenGL: Bool { get }

    
    // MARK: Input
    @objc func pollControllers()
    
    // MARK: Save States
    @objc func saveStateToFileAtPath(fileName: String) async throws
    @objc func loadStateFromFileAtPath(fileName: String) async throws

//    @objc func saveStateToFileAtPath(fileName: String, completionHandler block: @escaping (Bool, Error?) -> Void)
//    @objc func loadStateFromFileAtPath(fileName: String, completionHandler block: @escaping (Bool, Error?) -> Void)
}

#if !os(macOS) && !os(watchOS)
@objc
extension PVEmulatorCore: ResponderClient {
    @objc open func send(event: UIEvent?) {
        #warning("This is empty in the ObjC version too, but why does this exist? @JoeMatt")
    }
}
#endif

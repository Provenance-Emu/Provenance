//
//  MupenGameCore.swift
//  PVMupenGameCore
//
//  Created by Joseph Mattiello on 8/18/24.
//
import Foundation
import GameController
import PVSupport
import PVCoreBridge
import PVLogging
import PVEmulatorCore
import PVSettings
import Defaults

#if SWIFT_MODULE
import PVMupen64PlusCore
#endif

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import OpenGL.GL3
import GLUT
#else
import OpenGLES
import GLKit
#endif

#if os(tvOS)
let RESIZE_TO_FULLSCREEN: Bool = true
#else
let RESIZE_TO_FULLSCREEN: Bool = Defaults[.nativeScaleEnabled]
#endif

extension m64p_core_param: @retroactive Hashable, @retroactive Equatable, @retroactive Codable {
    
}

@objc public class MupenGameCore: PVEmulatorCore, @unchecked Sendable {
    
    // MARK: - Properties
    
    @objc var videoWidth: Int = 0
    @objc var videoHeight: Int = 0
    @objc var videoBitDepth: Int = 0
    
    @objc var mupenSampleRate: Double = 0
    @objc var videoDepthBitDepth: Int = 0
    @objc var isNTSC: Bool = false
    @objc var dualJoystick: Bool = false
    
    var padData: [[UInt8]] = Array(repeating: Array(repeating: 0, count: PVN64Button.count.rawValue), count: 4)
    var xAxis: [Int8] = Array(repeating: 0, count: 4)
    var yAxis: [Int8] = Array(repeating: 0, count: 4)
    
    public var controllerMode: [EmulatorCoreRumbleDataSource.ControllerMode] = [.none, .none, .none, .none]
    var inputQueue: OperationQueue!
    
    private var romData: Data?
    private var mupenWaitToBeginFrameSemaphore: DispatchSemaphore!
    private var coreWaitToEndFrameSemaphore: DispatchSemaphore!
    private var emulatorState: m64p_emu_state = M64EMU_STOPPED
    private var callbackQueue: DispatchQueue!
    private typealias CallbackHandler = @convention(c) (m64p_core_param, Int) -> Bool
    private var callbackHandlers: [Int: Array<CallbackHandler>] = [:]
    private var coreHandle: UnsafeMutableRawPointer?
    private var plugins: [UnsafeMutableRawPointer?] = Array(repeating: nil, count: 4)
    
    // MARK: - Initialization
    
    required init() {
        super.init()
        
        mupenWaitToBeginFrameSemaphore = DispatchSemaphore(value: 0)
        coreWaitToEndFrameSemaphore = DispatchSemaphore(value: 0)
        
        calculateSize()
        
        videoBitDepth = 32
        videoDepthBitDepth = 0
        mupenSampleRate = 33600
        isNTSC = true
        
        callbackQueue = DispatchQueue(label: "org.openemu.MupenGameCore.CallbackHandlerQueue", attributes: [])
        
        inputQueue = OperationQueue()
        inputQueue.name = "mupen.input"
        inputQueue.qualityOfService = .userInitiated
        inputQueue.maxConcurrentOperationCount = 4
    }
    
    deinit {
        SetStateCallback(nil, nil)
        SetDebugCallback(nil, nil)
        
        inputQueue.cancelAllOperations()
        
        pluginsUnload()
        detachCoreLib()
    }
    
    // MARK: - Public Methods
    
    func addHandler(forType paramType: m64p_core_param, usingBlock block: @escaping (m64p_core_param, Int) -> Bool) {
        if paramType == M64CORE_EMU_STATE && emulatorState.rawValue != 0 && !block(M64CORE_EMU_STATE, emulatorState) {
            return
        }
        
        callbackQueue.async {
            var callbacks = self.callbackHandlers[Int(paramType)] ?? Array<(m64p_core_param, Int) -> Bool>()
            callbacks.insert(block)
            self.callbackHandlers[Int(paramType)] = callbacks
        }
    }
    
    func didReceiveStateChange(forParamType paramType: m64p_core_param, value newValue: Int) {
        if paramType == M64CORE_EMU_STATE {
            emulatorState = m64p_emu_state(rawValue: Int32(newValue))
        }
        
        let runCallbacksForType: (m64p_core_param) -> Void = { type in
            if let callbacks = self.callbackHandlers[Int(type)] {
                self.callbackHandlers[Int(type)] = callbacks.filter { $0(paramType, newValue) }
            }
        }
        
        callbackQueue.async {
            runCallbacksForType(paramType)
            runCallbacksForType(m64p_core_param(rawValue: 0))
        }
    }
    
    @MainActor func loadFile(atPath path: String) throws -> Bool {
        let coreBundle = Bundle.main
        
        guard let batterySavesDirectory = batterySavesPath else { return false }
        try FileManager.default.createDirectory(atPath: batterySavesDirectory, withIntermediateDirectories: true, attributes: nil)
        
        let romFolder = (path as NSString).deletingLastPathComponent
        let configPath = (romFolder as NSString).appendingPathComponent("/config/")
        let dataPath = (romFolder as NSString).appendingPathComponent("/data/")
        
        // Create config and data paths
        let fileManager = FileManager.default
        for path in [configPath, dataPath] {
            if !fileManager.fileExists(atPath: configPath) {
                do {
                    try fileManager.createDirectory(atPath: configPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    ELOG("Failed to create path. \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        parseOptions()
        
        // Create hires folder placement
        do {
            try createHiResFolder(romFolder)
        } catch {
            ELOG("\(error.localizedDescription)")
            throw error
        }
        
        // Copy default ini files to the config path
        do {
            try copyIniFiles(configPath)
            // Rice looks in the data path for some reason, copy it there too
            try copyIniFiles(dataPath)
        } catch {
            ELOG("\(error.localizedDescription)")
            throw error
        }
        
        // Setup configs
        ConfigureAll(romFolder)
        
        // open core here
        CoreStartup(FRONTEND_API_VERSION, configPath, dataPath, Unmanaged.passUnretained(self).toOpaque(), MupenDebugCallback, Unmanaged.passUnretained(self).toOpaque(), MupenStateCallback)
        
        // Setup configs
        ConfigureAll(romFolder)
        
        // Disable the built in speed limiter
        CoreDoCommand(M64CMD_CORE_STATE_SET, M64CORE_SPEED_LIMITER, 0)
        
        // Load ROM
        guard let romData = try? Data(contentsOf: URL(fileURLWithPath: path)), !romData.isEmpty else {
            ELOG("Error loading ROM at path: \(path)\n File does not exist.")
            throw NSError(domain: PVEmulatorCoreErrorCode.PVEmulatorCoreErrorDomain, code: PVEmulatorCoreErrorCode.couldNotLoadRom.rawValue, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load game.",
                NSLocalizedFailureReasonErrorKey: "Mupen64Plus find the game file.",
                NSLocalizedRecoverySuggestionErrorKey: "Check the file hasn't been moved or deleted."
            ])
        }
        
        self.romData = romData
        
        let openStatus = CoreDoCommand(M64CMD_ROM_OPEN, Int32(romData.count), romData.withUnsafeBytes { $0.baseAddress })
        guard openStatus == M64ERR_SUCCESS else {
            ELOG("Error loading ROM at path: \(path)\n Error code was: \(openStatus)")
            throw NSError(domain: PVEmulatorCoreErrorCode.PVEmulatorCoreErrorDomain, code: PVEmulatorCoreErrorCode.couldNotLoadRom.rawValue, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load game.",
                NSLocalizedFailureReasonErrorKey: "Mupen64Plus failed to load game.",
                NSLocalizedRecoverySuggestionErrorKey: "Check the file isn't corrupt and supported Mupen64Plus ROM format."
            ])
        }
        
        coreHandle = dlopen_myself()
        
        // Load Plugin
        let loadPlugin: (m64p_plugin_type, String) -> Bool = { pluginType, pluginName in
            let frameworkPath = "\(pluginName).framework/\(pluginName)"
            let frameworkBundle = Bundle.main
            let rspPath = (frameworkBundle.privateFrameworksPath! as NSString).appendingPathComponent(frameworkPath)
            
            guard let rsp_handle = dlopen(rspPath, RTLD_LAZY | RTLD_LOCAL) else {
                return false
            }
            
            guard let rsp_start = unsafeBitCast(osal_dynlib_getproc(rsp_handle, "PluginStartup"), to: ptr_PluginStartup.self) else {
                return false
            }
            
            let err = rsp_start(self.coreHandle, Unmanaged.passUnretained(self).toOpaque(), MupenDebugCallback)
            guard err == M64ERR_SUCCESS else {
                ELOG("Error code \(err) loading plugin of type \(pluginType), name: \(pluginName)")
                return false
            }
            
            let attachErr = CoreAttachPlugin(pluginType, rsp_handle)
            guard attachErr == M64ERR_SUCCESS else {
                ELOG("Error code \(attachErr) attaching plugin of type \(pluginType), name: \(pluginName)")
                return false
            }
            
            // Store handle for later unload
            self.plugins[Int(pluginType.rawValue)] = rsp_handle
            
            return true
        }
        
        // Load Video
        var success = false
        
#if !targetEnvironment(macCatalyst) && !os(macOS)
        let context = bestContext()
#endif
        
        if MupenGameCore.useRice {
            success = loadPlugin(.M64PLUGIN_GFX, "PVMupen64PlusVideoRice")
            ptr_PV_ForceUpdateWindowSize = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_PV_ForceUpdateWindowSize")
        } else {
            if glesVersion.rawValue < .GLESVersion3 || MemoryLayout<Int>.size == 4 {
                ILOG("No 64bit or GLES3. Using RICE GFX plugin.")
                success = loadPlugin(.M64PLUGIN_GFX, "PVMupen64PlusVideoRice")
                ptr_PV_ForceUpdateWindowSize = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_PV_ForceUpdateWindowSize")
            } else {
                ILOG("64bit and GLES3. Using GLiden64 GFX plugin.")
                success = loadPlugin(.M64PLUGIN_GFX, "PVMupen64PlusVideoGlideN64")
                
                ptr_SetOSDCallback = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "SetOSDCallback")
                ptr_SetOSDCallback?(PV_DrawOSD)
            }
        }
        
        guard success else {
            throw NSError(domain: PVEmulatorCoreErrorDomain, code: PVEmulatorCoreErrorCodeCouldNotLoadRom, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load game.",
                NSLocalizedFailureReasonErrorKey: "Mupen64Plus failed to load GFX Plugin.",
                NSLocalizedRecoverySuggestionErrorKey: "Provenance may not be compiled correctly."
            ])
        }
        
        // Load Audio
        audio.aiDacrateChanged = MupenAudioSampleRateChanged
        audio.aiLenChanged = MupenAudioLenChanged
        audio.initiateAudio = MupenOpenAudio
        audio.setSpeedFactor = MupenSetAudioSpeed
        audio.romOpen = unsafeBitCast(MupenAudioRomOpen, to: (@convention(c) () -> Int32).self)
        audio.romClosed = MupenAudioRomClosed
        
        plugin_start(.M64PLUGIN_AUDIO)
        
        // Load Input
        input.getKeys = MupenGetKeys
        input.initiateControllers = MupenInitiateControllers
        input.controllerCommand = MupenControllerCommand
        plugin_start(.M64PLUGIN_INPUT)
        
        if MupenGameCore.useCXD4 {
            // Load RSP
            // Configure if using rsp-cxd4 plugin
            var configRSP: m64p_handle?
            ConfigOpenSection("rsp-cxd4", &configRSP)
            var usingHLE: Int32 = 1 // Set to 0 if using LLE GPU plugin/software rasterizer such as Angry Lion
            ConfigSetParameter(configRSP, "DisplayListToGraphicsPlugin", .M64TYPE_BOOL, &usingHLE)
            ConfigSaveSection("rsp-cxd4")
            
            success = loadPlugin(.M64PLUGIN_RSP, "PVRSPCXD4")
        } else {
            success = loadPlugin(.M64PLUGIN_RSP, "PVMupen64PlusRspHLE")
        }
        
        guard success else {
            throw NSError(domain: PVEmulatorCoreErrorDomain, code: PVEmulatorCoreErrorCodeCouldNotLoadRom, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load game.",
                NSLocalizedFailureReasonErrorKey: "Mupen64Plus failed to load RSP Plugin.",
                NSLocalizedRecoverySuggestionErrorKey: "Provenance may not be compiled correctly."
            ])
        }
        
#if !os(macOS)
        if RESIZE_TO_FULLSCREEN {
            if let keyWindow = UIApplication.shared.keyWindow {
                let fullScreenSize = keyWindow.bounds.size
                let widthScale = floor(fullScreenSize.height / CGFloat(WIDTHf))
                let heightScale = floor(fullScreenSize.height / CGFloat(WIDTHf))
                let scale = max(min(widthScale, heightScale), 1)
                let widthScaled = scale * CGFloat(WIDTHf)
                let heightScaled = scale * CGFloat(HEIGHTf)
                
                tryToResizeVideo(to: CGSize(width: widthScaled, height: heightScaled))
            }
        }
#endif
        
        // Setup configs
        ConfigureAll(romFolder)
        
#if DEBUG
        if let defaults = UserDefaults.standard.dictionaryRepresentation().debugDescription {
            DLOG("defaults: \n\(defaults)")
        }
#endif
        
        return true
    }
    
#if !targetEnvironment(macCatalyst) && !os(macOS)
    func bestContext() -> EAGLContext {
        if let context = EAGLContext(api: .openGLES3) {
            glesVersion = .GLESVersion3
            return context
        } else if let context = EAGLContext(api: .openGLES2) {
            glesVersion = .GLESVersion2
            return context
        }
        fatalError("No OpenGL ES 2.0 or 3.0 context available")
    }
#endif
    
    public override func startEmulation() {
        parseOptions()
        
        if !isRunning {
            super.startEmulation()
            Thread.detachNewThread(selector: #selector(runMupenEmuThread), toTarget: self, with: nil)
        }
    }
    
    @objc func runMupenEmuThread() {
        autoreleasepool {
            renderDelegate?.startRenderingOnAlternateThread()
            if CoreDoCommand(M64CMD_EXECUTE, 0, nil) != M64ERR_SUCCESS {
                ELOG("Core execute did not exit correctly")
            } else {
                ILOG("Core finished executing main")
            }
            
            if CoreDetachPlugin(M64PLUGIN_GFX) != M64ERR_SUCCESS {
                ELOG("Failed to detach GFX plugin")
            } else {
                ILOG("Detached GFX plugin")
            }
            
            if CoreDetachPlugin(M64PLUGIN_RSP) != M64ERR_SUCCESS {
                ELOG("Failed to detach RSP plugin")
            } else {
                ILOG("Detached RSP plugin")
            }
            
            pluginsUnload()
            
            if CoreDoCommand(M64CMD_ROM_CLOSE, 0, nil) != M64ERR_SUCCESS {
                ELOG("Failed to close ROM")
            } else {
                ILOG("ROM closed")
            }
            
            // Unlock rendering thread
            coreWaitToEndFrameSemaphore.signal()
            
            super.stopEmulation()
            
            if CoreShutdown() != M64ERR_SUCCESS {
                ELOG("Core shutdown failed")
            } else {
                ILOG("Core shutdown successfully")
            }
        }
    }
    
    func pluginsUnload() -> m64p_error {
        // shutdown and unload frameworks for plugins
        
        typealias PluginShutdownFunc = @convention(c) () -> m64p_error
        
        for i in 0..<4 {
            guard let plugin = plugins[i] else { continue }
            
            if let pluginShutdown = unsafeBitCast(osal_dynlib_getproc(plugin, "PluginShutdown"), to: PluginShutdownFunc?.self) {
                let status = pluginShutdown()
                if status == M64ERR_SUCCESS {
                    ILOG("Shutdown plugin")
                } else {
                    ELOG("Shutdown plugin type \(i) failed: \(status)")
                }
            }
            
            if dlclose(plugin) != 0 {
                ELOG("Failed to dlclose plugin type \(i)")
            } else {
                ILOG("dlclosed plugin type \(i)")
            }
            
            plugins[i] = nil
        }
        
        return M64ERR_SUCCESS
    }
    
    var frameTime: DispatchTime {
        let frameTime = 1.0 / frameInterval
        return .now() + .seconds(Int(frameTime)) + .nanoseconds(Int((frameTime.truncatingRemainder(dividingBy: 1)) * Double(NSEC_PER_SEC)))
    }
    
    func videoInterrupt() {
        coreWaitToEndFrameSemaphore.signal()
        _ = mupenWaitToBeginFrameSemaphore.wait(timeout: frameTime)
    }
    
    public override func swapBuffers() {
        renderDelegate?.didRenderFrameOnAlternateThread()
    }
    
    func executeFrame(skippingFrame skip: Bool) {
        mupenWaitToBeginFrameSemaphore.signal()
        _ = coreWaitToEndFrameSemaphore.wait(timeout: frameTime)
    }
    
    public override func executeFrame() {
        executeFrame(skippingFrame: false)
    }
    
    public override func setPauseEmulation(_ flag: Bool) {
        super.setPauseEmulation(flag)
        parseOptions()
        // TODO: Fix pause
        // CoreDoCommand(M64CMD_PAUSE, flag ? 1 : 0, nil)
        
        if flag {
            mupenWaitToBeginFrameSemaphore.signal()
            frontBufferCondition.lock()
            frontBufferCondition.signal()
            frontBufferCondition.unlock()
        }
    }
    
    public override func stopEmulation() {
        inputQueue.cancelAllOperations()
        
        CoreDoCommand(M64CMD_STOP, 0, nil)
        
        mupenWaitToBeginFrameSemaphore.signal()
        frontBufferCondition.lock()
        frontBufferCondition.signal()
        frontBufferCondition.unlock()
        
        super.stopEmulation()
    }
    
    override public func resetEmulation() {
        // FIXME: do we want/need soft reset? It doesn't seem to work well with sending M64CMD_RESET alone
        // FIXME: (astrange) should this method worry about this instance's dispatch semaphores?
        CoreDoCommand(M64CMD_RESET, 1 /* hard reset */, nil)
        mupenWaitToBeginFrameSemaphore.signal()
        frontBufferCondition.lock()
        frontBufferCondition.signal()
        frontBufferCondition.unlock()
    }
    
    func tryToResizeVideo(to size: CGSize) {
        DLOG("Calling set video mode size to (\(size.width),\(size.height))")
        
        VidExt_SetVideoMode(Int32(size.width), Int32(size.height), 32, M64VIDEO_FULLSCREEN, 0)
        if let ptr_PV_ForceUpdateWindowSize = ptr_PV_ForceUpdateWindowSize {
            ptr_PV_ForceUpdateWindowSize(Int32(size.width), Int32(size.height))
        }
    }
}

// MARK: - Private
extension MupenGameCore {
    private func calculateSize() {
        #if !os(macOS)
        if RESIZE_TO_FULLSCREEN {
            if let size = UIApplication.shared.keyWindow?.bounds.size {
                let widthScale = size.width / CGFloat(WIDTHf)
                let heightScale = size.height / CGFloat(HEIGHTf)
                var scale: CGFloat
                if Defaults[.integerScaleEnabled] {
                    scale = max(min(floor(widthScale), floor(heightScale)), 1)
                } else {
                    scale = max(min(widthScale, heightScale), 1)
                }
                videoWidth = Int(scale * CGFloat(WIDTHf))
                videoHeight = Int(scale * CGFloat(HEIGHTf))
                DLOG("Upscaling on: scale rounded to (\(scale))")
            }
        } else {
            videoWidth = WIDTH
            videoHeight = HEIGHT
        }
        #else
        videoWidth = WIDTH
        videoHeight = HEIGHT
        #endif
    }

}

// MARK: - Extensions

extension MupenGameCore: PVN64SystemResponderClient {
#warning("Finish me")
    public func didMoveJoystick(_ button: PVCoreBridge.PVN64Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {

    }
    
    public func didPush(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {

    }
    
    public func didRelease(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {

    }
    
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? {
        return nil
    }
    
    public func didPush(_ button: Int, forPlayer player: Int) {

    }
    
    public func didRelease(_ button: Int, forPlayer player: Int) {

    }
    
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {

    }
}

#if !os(macOS)
extension MupenGameCore: GLKViewDelegate {
#warning("Finish me")
    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        
    }
}
#endif

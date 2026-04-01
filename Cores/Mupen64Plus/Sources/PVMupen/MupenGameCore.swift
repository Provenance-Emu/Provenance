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
import PVMupen64PlusBridge

//#if SWIFT_MODULE
//import PVMupen64PlusCore
//#endif

#if os(iOS)
import UIKit
#endif

#if os(macOS) || targetEnvironment(macCatalyst)
import OpenGL.GL3
import GLUT
#elseif !os(watchOS)
import OpenGLES
import GLKit
#endif

//#if os(tvOS)
//let RESIZE_TO_FULLSCREEN: Bool = true
//#else
//let RESIZE_TO_FULLSCREEN: Bool = Defaults[.nativeScaleEnabled]
//#endif
//
//extension m64p_core_param: @retroactive Hashable, @retroactive Equatable, @retroactive Codable {
//    
//}

@objc public class MupenGameCore: PVEmulatorCore, @unchecked Sendable {
    
    /// Mupen64Plus uses a JIT recompiler for better N64 performance; interpreter available as fallback.
    public override var jitRequirement: PVJITRequirement { .optional(fallback: "Interpreter") }
    
    //    // MARK: - Properties
    //    
    //    @objc var videoWidth: Int = 0
    //    @objc var videoHeight: Int = 0
    //    @objc var videoBitDepth: Int = 0
    //    
    //    @objc var mupenSampleRate: Double = 0
    //    @objc var videoDepthBitDepth: Int = 0
    //    @objc var isNTSC: Bool = false
    //    @objc var dualJoystick: Bool = false
    //    
    //    var padData: [[UInt8]] = Array(repeating: Array(repeating: 0, count: PVN64Button.count.rawValue), count: 4)
    //    var xAxis: [Int8] = Array(repeating: 0, count: 4)
    //    var yAxis: [Int8] = Array(repeating: 0, count: 4)
    //    
    //    public var controllerMode: [EmulatorCoreRumbleDataSource.ControllerMode] = [.none, .none, .none, .none]
    //    var inputQueue: OperationQueue!
    //    
    //    private var romData: Data?
    //    private var mupenWaitToBeginFrameSemaphore: DispatchSemaphore!
    //    private var coreWaitToEndFrameSemaphore: DispatchSemaphore!
    //    private var emulatorState: m64p_emu_state = M64EMU_STOPPED
    //    private var callbackQueue: DispatchQueue!
    //    private typealias CallbackHandler = @convention(c) (m64p_core_param, Int) -> Bool
    //    private var callbackHandlers: [Int: Array<CallbackHandler>] = [:]
    //    private var coreHandle: UnsafeMutableRawPointer?
    //    private var plugins: [UnsafeMutableRawPointer?] = Array(repeating: nil, count: 4)
    
    // MARK: - RetroAchievements backing storage
    
    /// Weak reference to the OSD delegate (stored here because Swift extensions
    /// cannot add stored properties).
    weak var _achievementsDelegate: (any RetroAchievementsOSDDelegate)?
    
    /// Hardcore mode flag — when true, save-state loads are blocked.
    var _hardcoreMode: Bool = false
    
    /// Whether the achievement runtime is currently active for the loaded ROM.
    var _achievementsActive: Bool = false
    
    // MARK: - Initialization
    
    public var _bridge: PVMupenBridge = .init()
    
    required init() {
        super.init()
        self.bridge = (PVMupenBridge() as! any ObjCBridgedCoreBridge)
    }
}
    
// MARK: - Extensions

extension MupenGameCore: PVN64SystemResponderClient {
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: PVCoreBridge.PVN64Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didPush(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (bridge as! PVN64SystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension MupenGameCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        MupenGameCoreOptions.options
    }
}

// MARK: - TransferPakSupport

extension MupenGameCore: TransferPakSupport {
    public var transferPakSlotCount: Int { 4 }

    public func setTransferPakROM(_ rom: TransferPakROM?, forPort port: Int) {
        let mupenBridge = _bridge
        mupenBridge.setGBCartROMPath(
            rom?.romPath.path,
            savePath: rom?.savePath?.path,
            forPort: port
        )
        // Enable Transfer Pak plugin mode on this controller port when a cart is inserted.
        // Value 4 = PLUGIN_TRANSFER_PAK, value 2 = PLUGIN_MEMPAK (fallback when no cart).
        let mode = rom != nil ? 4 : 2
        mupenBridge.setMode(mode, forController: port)
    }

    public func transferPakROM(forPort port: Int) -> TransferPakROM? {
        guard port >= 0 && port < 4 else { return nil }
        let mupenBridge = _bridge
        guard let romPathStr = mupenBridge.gbCartROMPath(forPort: port) else { return nil }
        let romURL = URL(fileURLWithPath: romPathStr)
        let saveURL = mupenBridge.gbCartSavePath(forPort: port).map { URL(fileURLWithPath: $0) }
        return TransferPakROM(romPath: romURL, savePath: saveURL)
    }
}

extension MupenGameCore: GameWithCheat {
    public var supportsCheatCode: Bool { true }

    public var cheatCodeTypes: [String] {
        return _bridge.cheatCodeTypes()
    }

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        return _bridge.setCheatWithCode(code, type: type, codeType: codeType, cheat: cheatIndex, enabled: enabled)
    }

    public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }
}

//
//#if !os(macOS)
//extension MupenGameCore: GLKViewDelegate {
//#warning("Finish me")
//    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
//        
//    }
//}
//#endif

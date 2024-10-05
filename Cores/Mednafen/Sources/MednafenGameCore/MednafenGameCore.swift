//
//  MednafenGameCore.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/8/18.
//

import PVSupport
import Foundation

import PVCoreBridge

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
import MednafenGameCoreC
import MednafenGameCoreBridge
import MednafenGameCoreOptions
public import PVEmulatorCore

import Foundation
                                           
@objc
@objcMembers
open class MednafenGameCore: PVEmulatorCore, @unchecked Sendable {
//    @objc public var isStartPressed: Bool = false
//    @objc public var isSelectPressed: Bool = false
//    @objc public var isAnalogModePressed: Bool = false
//    @objc public var isL3Pressed: Bool = false
//    @objc public var isR3Pressed: Bool = false
//    
//    @objc public var inputBuffer: [[UInt32]] = Array(repeating: [], count: 13)
//    @objc public var axis: [Int16] = Array(repeating: 0, count: 8)
//    @objc public var videoWidth: Int = 0
//    @objc public var videoHeight: Int = 0
//    @objc public var videoOffsetX: Int = 0
//    @objc public var videoOffsetY: Int = 0
//    @objc public var multiTapPlayerCount: Int = 0
//    private var romName: String = ""
//    private var sampleRate: Double = 0
//    @objc public var masterClock: Double = 0
//    
//    @objc public var _isSBIRequired: Bool = false
//    
//    @objc public var mednafenCoreModule: String = ""
//    @objc public var mednafenCoreTiming: TimeInterval = 0
//    
//    @objc public var systemType: MednaSystem = .gb
//    @objc public var maxDiscs: UInt = 0
//    
//    @objc public var video_opengl: Bool = false
//    
//    @objc public func setMedia(_ open: Bool, forDisc disc: UInt) {
//        Mednafen.MDFNI_SetMedia(0, open ? 0 : 2, uint32(disc), 0);
//
//    }
//    @preconcurrency
//    @objc public func changeDisplayMode() {
//        if (self.systemType == .virtualBoy)
//        {
//            switch (MDFN_IEN_VB.mednafenCurrentDisplayMode)
//            {
//            case 0: // (2D) red/black
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFF0000, 0x000000);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(true);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 1: // (2D) white/black
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFFFFFF, 0x000000);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(true);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 2: // (2D) purple/black
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFF00FF, 0x000000);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(true);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 3: // (3D) red/blue
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFF0000, 0x0000FF);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(false);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 4: // (3D) red/cyan
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFF0000, 0x00B7EB);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(false);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 5: // (3D) red/electric cyan
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFF0000, 0x00FFFF);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(false);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 6: // (3D) red/green
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFF0000, 0x00FF00);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(false);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 7: // (3D) green/red
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0x00FF00, 0xFF0000);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(false);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode += 1;
//                break;
//                
//            case 8: // (3D) yellow/blue
//                MDFN_IEN_VB.VIP_SetAnaglyphColors(0xFFFF00, 0x0000FF);
//                MDFN_IEN_VB.VIP_SetParallaxDisable(false);
//                MDFN_IEN_VB.mednafenCurrentDisplayMode = 0;
//                break;
//                
//            default:
//                return;
//                break;
//            }
//        }
//    }
//#warning("This is a stub")
//    @objc public func getGame() -> UnsafeRawPointer? { return nil }
    
    fileprivate var _bridge: MednafenGameCoreBridge = .init()
    public required init() {
        super.init()
        self.bridge = _bridge as? any ObjCBridgedCoreBridge
    }
}

@objc extension MednafenGameCore: PVPSXSystemResponderClient, PVWonderSwanSystemResponderClient, PVVirtualBoySystemResponderClient, PVPCESystemResponderClient, PVPCFXSystemResponderClient, PVPCECDSystemResponderClient, PVLynxSystemResponderClient, PVNeoGeoPocketSystemResponderClient, PVSNESSystemResponderClient, PVNESSystemResponderClient, PVGBSystemResponderClient, PVGBASystemResponderClient, PVSaturnSystemResponderClient {
    
    // MARK: - Controls
    /// PSX
    public func didPush(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didRelease(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSXButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    /// Wondersan
    public func didPush(_ button: PVCoreBridge.PVWSButton, forPlayer player: Int) {
        (_bridge as! PVWonderSwanSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVWSButton, forPlayer player: Int) {
        (_bridge as! PVWonderSwanSystemResponderClient).didRelease(button, forPlayer: player)
    }
    // VirtualBoy
    public func didPush(_ button: PVCoreBridge.PVVBButton, forPlayer player: Int) {
        (_bridge as! PVVirtualBoySystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVVBButton, forPlayer player: Int) {
        (_bridge as! PVVirtualBoySystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// PCE
    public func didPush(_ button: PVCoreBridge.PVPCEButton, forPlayer player: Int) {
        (_bridge as! PVPCESystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPCEButton, forPlayer player: Int) {
        (_bridge as! PVPCESystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// PCFX
    public func didPush(_ button: PVCoreBridge.PVPCFXButton, forPlayer player: Int) {
        (_bridge as! PVPCFXSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPCFXButton, forPlayer player: Int) {
        (_bridge as! PVPCFXSystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// PCECD
    public func didPush(_ button: PVCoreBridge.PVPCECDButton, forPlayer player: Int) {
        (_bridge as! PVPCECDSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPCECDButton, forPlayer player: Int) {
        (_bridge as! PVPCECDSystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// Lynx
    public func didPush(LynxButton: PVCoreBridge.PVLynxButton, forPlayer player: Int) {
        (_bridge as! PVLynxSystemResponderClient).didPush(LynxButton: LynxButton, forPlayer: player)
    }
    public func didRelease(LynxButton: PVCoreBridge.PVLynxButton, forPlayer player: Int) {
        (_bridge as! PVLynxSystemResponderClient).didRelease(LynxButton: LynxButton, forPlayer: player)
    }
    /// NeoGeo Pocket
    public func didPush(_ button: PVCoreBridge.PVNGPButton, forPlayer player: Int) {
        (_bridge as! PVNeoGeoPocketSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNGPButton, forPlayer player: Int) {
        (_bridge as! PVNeoGeoPocketSystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// SNES
    public func didPush(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (_bridge as! PVSNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (_bridge as! PVSNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// NES
    public func didPush(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// GameBoy
    public func didPush(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// GameBoy Advanced
    public func didPush(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didRelease(button, forPlayer: player)
    }
    /// Saturn
    public func didPush(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didRelease(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVSaturnButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    // MARK: Button Values
//    @objc func ssValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func gbValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func gbaValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func snesValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func nesValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func neoGeoValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func pceValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func psxAnalogControllerValue(forButtonID buttonID: UInt, forController controller: GCController) -> Float { return 0 }
//    @objc func psxControllerValue(forButtonID buttonID: UInt, forController controller: GCController, withAnalogMode analogMode: Bool) -> Int { return 0 }
//    @objc func virtualBoyControllerValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
//    @objc func wonderSwanControllerValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
}

extension MednafenGameCore: DiscSwappable {
    public var numberOfDiscs: UInt {
        return _bridge.maxDiscs
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        switch _bridge.systemType {
        case .PSX:
            return numberOfDiscs > 1
        default:
            return false
        }
    }

    public func swapDisc(number: UInt) {
        setPauseEmulation(false)

        let index = number - 1
        _bridge.setMedia(true, forDisc: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            _bridge.setMedia(false, forDisc: index)
        }
    }
}

extension MednafenGameCore: CoreActions {
    
    enum Actions {
        static var changePalette: CoreAction { CoreAction(title: "Change Palette", options: nil) }
    }
    
    public var coreActions: [CoreAction]? {
        switch _bridge.systemType {
        case .virtualBoy:
            return [Actions.changePalette]
        default:
            return nil
        }
    }

    public func selected(action: CoreAction) {
        switch action {
        case Actions.changePalette:
            _bridge.changeDisplayMode()
        default:
            WLOG("Unknown action: " + action.title)
        }
    }
}

extension MednafenGameCore: GameWithCheat {
    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        _bridge.setCheat(code: code, type: type, codeType: codeType, cheatIndex: cheatIndex, enabled: enabled)
    }
    
    public var supportsCheatCode: Bool {
        _bridge.supportsCheatCode
    }
    
    public var cheatCodeTypes: [String] {
        _bridge.cheatCodeTypes
    }
}

extension MednafenGameCoreBridge: GameWithCheat {
    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            try self.setCheat(code, setType: type, setCodeType:codeType, setIndex: cheatIndex, setEnabled: enabled)
            return true
        } catch let error {
            ELOG("Error setCheat \(error)")
            return false
        }
    }

    public var cheatCodeTypes: [String] {
        return self.getCheatCodeTypes()
    }

    public var supportsCheatCode: Bool
    {
        return self.getCheatSupport();
    }
}

extension MednafenGameCore: CoreOptional {
    public static var options: [CoreOption] {
        MednafenGameCoreOptions.options
    }
}

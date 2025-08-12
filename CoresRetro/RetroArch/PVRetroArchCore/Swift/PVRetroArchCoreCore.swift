//
//  PVJaguarGameCore.swift
//  PVVirtualJaguar
//
//  Created by Joseph Mattiello on 5/21/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
#if canImport(GameController)
import GameController
#endif
#if canImport(OpenGLES)
import OpenGLES
import OpenGLES.ES3
#endif
import PVLogging
import PVAudio
import PVEmulatorCore
import PVCoreObjCBridge
internal import enum PVCoreBridge.PVDSButton
//import PVCoreBridge

@objc
@objcMembers
public class PVRetroArchCoreCore: PVEmulatorCore {

    public override var rendersToOpenGL: Bool { true }
    public override var isDoubleBuffered: Bool { true }
    public override var supportsSkins: Bool { true }
    public override var supportsAudioVisualizer: Bool { true }
    public override var supportsSaveStates: Bool {
        let unsupportedCores = [
            "dreamcast"
        ]
        return (!unsupportedCores.contains(self.systemIdentifier ?? "")
                && !unsupportedCores.contains(self.systemName))
                || core_info_current_supports_savestate()
    }

    // MARK: Lifecycle
    public lazy var _bridge: PVRetroArchCoreBridge = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}
// MARK: RetroArch
extension PVRetroArchCoreCore: PVRetroArchCoreResponderClient {
}

extension PVRetroArchCoreCore: DiscSwappable {
    public var currentGameSupportsMultipleDiscs: Bool {
        return _bridge.currentGameSupportsMultipleDiscs
    }

    public var numberOfDiscs: UInt {
        return _bridge.numberOfDiscs
    }
    public func swapDisc(number: UInt) {
        _bridge.swapDisc(withNumber: number)
    }
}

// MARK: GameBoy
extension PVRetroArchCoreCore: PVGBSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: GameBoy Advance
extension PVRetroArchCoreCore: PVGBASystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari 2600
extension PVRetroArchCoreCore: PV2600SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PV2600Button, forPlayer player: Int) {
        (_bridge as! PV2600SystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PV2600Button, forPlayer player: Int) {
        (_bridge as! PV2600SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari 5200
extension PVRetroArchCoreCore: PV5200SystemResponderClient {
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PV5200SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PV5200Button, withValue value: CGFloat, forPlayer player: Int) {
        (_bridge as! PV5200SystemResponderClient).didMoveJoystick(button, withValue: value, forPlayer: player)
    }

    public func didPush(_ button: PVCoreBridge.PV5200Button, forPlayer player: Int) {
        (_bridge as! PV5200SystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PV5200Button, forPlayer player: Int) {
        (_bridge as! PV5200SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari 7800
extension PVRetroArchCoreCore: PV7800SystemResponderClient {
    public func mouseMoved(at point: CGPoint) {
        (_bridge as! PV7800SystemResponderClient).mouseMoved(at: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        (_bridge as! PV7800SystemResponderClient).leftMouseDown(at: point)
    }
    public func leftMouseUp() {
        (_bridge as! PV7800SystemResponderClient).leftMouseUp()
    }
    public func didPush(_ button: PVCoreBridge.PV7800Button, forPlayer player: Int) {
        (_bridge as! PV7800SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PV7800Button, forPlayer player: Int) {
        (_bridge as! PV7800SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari Jaguar
extension PVRetroArchCoreCore: PVJaguarSystemResponderClient {
    public func didPush(jaguarButton button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didPush(jaguarButton: button, forPlayer: player)
    }
    public func didRelease(jaguarButton button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didRelease(jaguarButton: button, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didPush(jaguarButton: button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didRelease(jaguarButton: button, forPlayer: player)
    }
}

// MARK: NeoGeo PVNeoGeoSystemResponderClient
extension PVRetroArchCoreCore: PVNeoGeoSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVNeoGeoButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVNeoGeoSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVNeoGeoButton, forPlayer player: Int) {
        (_bridge as! PVNeoGeoSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNeoGeoButton, forPlayer player: Int) {
        (_bridge as! PVNeoGeoSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: NES
extension PVRetroArchCoreCore: PVNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: SNES
extension PVRetroArchCoreCore: PVSNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (_bridge as! PVSNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (_bridge as! PVSNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: N64
extension PVRetroArchCoreCore: PVN64SystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVN64Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVN64SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (_bridge as! PVN64SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (_bridge as! PVN64SystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: DS
extension PVRetroArchCoreCore: PVDSSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: 3DS
extension PVRetroArchCoreCore: PV3DSSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PV3DSButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PV3DSButton, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PV3DSButton, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: PSX
extension PVRetroArchCoreCore: PVPSXSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSXButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: PS2
extension PVRetroArchCoreCore: PVPS2SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPS2Button, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPS2Button, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didRelease(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVPS2Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
}
// MARK: Genesis
extension PVRetroArchCoreCore: PVGenesisSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGenesisButton, forPlayer player: Int) {
        (_bridge as! PVGenesisSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVGenesisButton, forPlayer player: Int) {
        (_bridge as! PVGenesisSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: SG1000
extension PVRetroArchCoreCore: PVSG1000SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSG1000Button, forPlayer player: Int) {
        (_bridge as! PVSG1000SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSG1000Button, forPlayer player: Int) {
        (_bridge as! PVSG1000SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: 32X
extension PVRetroArchCoreCore: PVSega32XSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSega32XButton, forPlayer player: Int) {
        (_bridge as! PVSega32XSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSega32XButton, forPlayer player: Int) {
        (_bridge as! PVSega32XSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Dreamcast
extension PVRetroArchCoreCore: PVDreamcastSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVDreamcastButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }

    public func didPush(_ button: PVCoreBridge.PVDreamcastButton, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDreamcastButton, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Intellivision
extension PVRetroArchCoreCore: PVIntellivisionSystemResponderClient {
    @nonobjc
    public func didMoveJoystick(_ button: PVCoreBridge.PVIntellivisionButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
//        (_bridge as! PVIntellivisionSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVIntellivisionButton, forPlayer player: Int) {
        (_bridge as! PVIntellivisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVIntellivisionButton, forPlayer player: Int) {
        (_bridge as! PVIntellivisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Colecovision
extension PVRetroArchCoreCore: PVColecoVisionSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVColecoVisionButton, forPlayer player: Int) {
        (_bridge as! PVColecoVisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVColecoVisionButton, forPlayer player: Int) {
        (_bridge as! PVColecoVisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Supervision
extension PVRetroArchCoreCore: PVSupervisionSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSupervisionButton, forPlayer player: Int) {
        (_bridge as! PVSupervisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSupervisionButton, forPlayer player: Int) {
        (_bridge as! PVSupervisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// PVDOSSystemResponderClient
extension PVRetroArchCoreCore: PVDOSSystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PVDOSButton, forPlayer player: Int) {
        (_bridge as! PVDOSSystemResponderClient).didRelease(button, forPlayer: player)
    }

    public var gameSupportsKeyboard: Bool {
        (_bridge as! PVDOSSystemResponderClient).gameSupportsKeyboard
    }

    public var requiresKeyboard: Bool {
        (_bridge as! PVDOSSystemResponderClient).requiresKeyboard
    }

    public func keyDown(_ key: GCKeyCode) {
        (_bridge as! PVDOSSystemResponderClient).keyDown(key)
    }
    public func keyUp(_ key: GCKeyCode) {
        (_bridge as! PVDOSSystemResponderClient).keyUp(key)
    }
    public var gameSupportsMouse: Bool {
        (_bridge as! PVDOSSystemResponderClient).gameSupportsMouse
    }
    public var requiresMouse: Bool {
        (_bridge as! PVDOSSystemResponderClient).requiresMouse
    }
    public func didScroll(_ cursor: GCDeviceCursor) {
        (_bridge as! PVDOSSystemResponderClient).didScroll(cursor)
    }

    public var mouseMovedHandler: GCMouseMoved? {
        (_bridge as! PVDOSSystemResponderClient).mouseMovedHandler
    }
    public func mouseMoved(atPoint point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).mouseMoved(at: point)
    }
    public func leftMouseDown(atPoint point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).leftMouseDown(at: point)
    }
    public func rightMouseDown(atPoint point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).rightMouseDown(atPoint: point)
    }
    public func rightMouseUp() {
        (_bridge as! PVDOSSystemResponderClient).rightMouseUp()
    }
    public func didPush(_ button: PVCoreBridge.PVDOSButton, forPlayer player: Int) {
        (_bridge as! PVDOSSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// MAME
extension PVRetroArchCoreCore: PVMAMESystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVMAMEButton, forPlayer player: Int) {
        (_bridge as! PVMAMESystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVMAMEButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVMAMESystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVMAMEButton, forPlayer player: Int) {
        (_bridge as! PVMAMESystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// 3DO
extension PVRetroArchCoreCore: PV3DOSystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PV3DOButton, forPlayer player: Int) {
        (_bridge as! PV3DOSystemResponderClient).didRelease(button, forPlayer: player)
    }

    public func didPush(_ button: PVCoreBridge.PV3DOButton, forPlayer player: Int) {
        (_bridge as! PV3DOSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// PCE
extension PVRetroArchCoreCore: PVPCESystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPCEButton, forPlayer player: Int) {
        (_bridge as! PVPCESystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPCEButton, forPlayer player: Int) {
        (_bridge as! PVPCESystemResponderClient).didPush(button, forPlayer: player)
    }
}

// PCE-CD
extension PVRetroArchCoreCore: PVPCECDSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPCECDButton, forPlayer player: Int) {
        (_bridge as! PVPCECDSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPCECDButton, forPlayer player: Int) {
        (_bridge as! PVPCECDSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// PCFX
extension PVRetroArchCoreCore: PVPCFXSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPCFXButton, forPlayer player: Int) {
        (_bridge as! PVPCFXSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPCFXButton, forPlayer player: Int) {
        (_bridge as! PVPCFXSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// PSP
extension PVRetroArchCoreCore: PVPSPSystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PVPSPButton, forPlayer player: Int) {
        (_bridge as! PVPSPSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSPButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSPSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVPSPButton, forPlayer player: Int) {
        (_bridge as! PVPSPSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// Sega Saturn
extension PVRetroArchCoreCore: PVSaturnSystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVSaturnButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didPush(button, forPlayer: player)
    }
}

//
//  PVJaguarGameCore.swift
//  PVVirtualJaguar
//
//  Created by Joseph Mattiello on 5/21/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
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

@objc
@objcMembers
final class PVPPSSPPCore: PVEmulatorCore, @unchecked Sendable {
    
    public override var supportsSkins: Bool { false }
    
    // PVEmulatorCoreBridged
    public lazy var _bridge: PVPPSSPPCoreBridge = .init()

#if canImport(GameController)
//    // MARK: Controls
//    @MainActor
//    @objc public init(valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil) {
//        self.valueChangedHandler = valueChangedHandler
//        self.core = PVJaguarCoreBridge(valueChangedHandler: valueChangedHandler)
//    }
//
//    @MainActor
//    @objc public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
#endif
    // MARK: Video

    // MARK: Lifecycle

    @objc public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
        _bridge.parseOptions()
    }
    
    public override func executeFrame() {
        bridge.executeFrame()
    }
}

extension PVPPSSPPCore: PVPSPSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPSPButton, forPlayer player: Int) {
        (bridge as! PVPSPSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVPSPButton, forPlayer player: Int) {
        (bridge as! PVPSPSystemResponderClient).didRelease(button, forPlayer: player)

    }
    
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSPButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (bridge as! PVPSPSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (bridge as! PVPSPSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
}

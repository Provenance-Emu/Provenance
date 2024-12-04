//
//  PVBeetlePSXCore.swift
//  PVBeetlePSX
//
//  Created by Joseph Mattiello on 8/15/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro

@objc
@objcMembers
open class PVBeetlePSXCore: PVEmulatorCore {

    lazy var _bridge: PVBeetlePSXCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVBeetlePSXCore: PVPSXSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSXButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didPush(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didRelease(button, forPlayer: player)
    }
}


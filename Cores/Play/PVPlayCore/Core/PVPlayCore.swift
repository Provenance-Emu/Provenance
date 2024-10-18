//
//  PVPlayCore.swift
//  PVPlay
//
//  Created by Joseph Mattiello on 3/8/18.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
import PVEmulatorCore

@objc
@objcMembers
open class PVPlayCore: PVEmulatorCore, @unchecked Sendable {

    // MARK: Lifecycle
    
    let _bridge: PVPlayCoreBridge = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVPlayCore: PVPS2SystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVPS2Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVPS2Button, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPS2Button, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVPlayCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVPlayCoreOptions.options
    }
}


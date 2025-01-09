//
//  PVTGBDual.swift
//  PVTGBDual
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVAudio
import PVEmulatorCore
import PVTGBDualCPP
import PVTGBDualBridge
import libtgbdual
#if canImport(GameController)
import GameController
#endif

@objc
@objcMembers
public final class PVTGBDualCore: PVEmulatorCore, @unchecked Sendable {
    
    // TGBDual
    private var _sampleRate: Double = 44100
    override public var audioSampleRate: Double { get {_sampleRate}
        set {
            _sampleRate = newValue
            bridge.audioSampleRate = newValue
        }}
//    // MARK: Lifecycle

    public required init() {
        super.init()
        self.bridge = PVTGBDualBridge() as! any ObjCBridgedCoreBridge
    }
}

extension PVTGBDualCore: PVGBSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (bridge as! PVGBSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (bridge as! PVGBSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

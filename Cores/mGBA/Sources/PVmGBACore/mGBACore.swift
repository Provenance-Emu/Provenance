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
import PVmGBABridge
//import libmGBA

@objc
@objcMembers
public class PVmGBACore: PVEmulatorCore {

    @objc public override var isDoubleBuffered: Bool { false }
    @objc public override var rendersToOpenGL: Bool { false }

    // MARK: Lifecycle
    package var _bridge: PVmGBAGameCoreBridge = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }

    // MARK: - RetroAchievements backing storage

    /// Weak reference to the OSD delegate (stored here because Swift extensions
    /// cannot add stored properties).
    weak var _achievementsDelegate: (any RetroAchievementsOSDDelegate)?

    /// Hardcore mode flag.
    var _hardcoreMode: Bool = false

    /// Whether the achievement runtime is currently active for the loaded game.
    var _achievementsActive: Bool = false
}

extension PVmGBACore: PVGBASystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didRelease(button, forPlayer: player)
    }
}

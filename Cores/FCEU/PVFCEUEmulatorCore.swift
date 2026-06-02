//
//  PVFCEUEmulatorCore.swift
//  PVFCEU
//
//  Created by Joseph Mattiello on 3/9/18.
//  Copyright © 2018 JamSoft. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVCoreObjCBridge

@objc
@objcMembers
open class PVFCEUEmulatorCore: PVEmulatorCore, @unchecked Sendable {

    // MARK: Lifecycle

    let _bridge: PVFCEUEmulatorCoreBridge = .init()

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

    // MARK: - RetroAchievements per-frame tick
    // The shared `tickAchievements()` (CoreRetroAchievements+RcheevosSession) is a
    // Swift protocol-extension method, so it is NOT reachable from the ObjC
    // `executeFrame` in the .mm bridge. Drive it from this Swift override, mirroring
    // PVSNESEmulatorCore. Without it, FCEU loads the rc_client session (prepareAchievements
    // is called) but `rc_client_do_frame` never runs, so NES achievements never evaluate.
    public override func executeFrame() {
        super.executeFrame()
        if achievementsActive {
            tickAchievements()
        }
    }
}

extension PVFCEUEmulatorCore: GameWithCheat {
    public var supportsCheatCode: Bool { true }

    public var cheatCodeTypes: [String] {
        return CheatCodeTypesMakeStringArray([.gameGenie])
    }

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        return _bridge.setCheat(code, setType: type, setEnabled: enabled)
    }

    public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }
}

extension PVFCEUEmulatorCore: PVNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVFCEUEmulatorCoreBridge: DiscSwappable {
    public var numberOfDiscs: UInt {
        return 2
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        return true
    }

    public func swapDisc(number: UInt) {
        internalSwapDisc(number)
    }
}

extension PVFCEUEmulatorCoreBridge: ArchiveSupport {
    public var supportedArchiveFormats: ArchiveSupportOptions {
        return [.gzip, .zip]
    }
}

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
    // The shared tick (CoreRetroAchievements+RcheevosSession, a `where Self: NSObject`
    // extension in PVRcheevosBridge) is unreachable from the ObjC `executeFrame` in the
    // .mm bridge, so without this NES loads the rc_client session (prepareAchievements
    // runs) but `rc_client_do_frame` never ticks → achievements never evaluate.
    // Routed through the existential so it resolves with only PVCoreBridge in scope
    // (FCEU's core target doesn't import PVRcheevosBridge); dispatch hits the real
    // NSObject witness, not the protocol's no-op default.
    public override func executeFrame() {
        super.executeFrame()
        guard let achievements = self as? (any CoreRetroAchievements), achievements.achievementsActive else { return }
        achievements.tickAchievements()
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

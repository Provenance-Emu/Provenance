//
//  PVVisualBoyAdvance.swift
//  PVVisualBoyAdvance
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
#if canImport(GameController)
import GameController
#endif
import PVCoreBridge
import PVLogging
import PVAudio
import PVEmulatorCore
import PVVisualBoyAdvanceOptions
import PVVisualBoyAdvanceBridge
import libvisualboyadvance

@objc
@objcMembers
open class PVVisualBoyAdvanceCore: PVEmulatorCore {

    // MARK: Lifecycle

    let _bridge: PVVisualBoyAdvanceBridge = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVVisualBoyAdvanceCore: GameWithCheat {
    public var supportsCheatCode: Bool { true }

    public var cheatCodeTypes: [String] {
        return _bridge.cheatCodeTypes()
    }

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        return _bridge.setCheat(withCode: code, type: type, codeType: codeType, cheatIndex: cheatIndex, enabled: enabled)
    }

    public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }
}

extension PVVisualBoyAdvanceCore: CoreOptional {
    public static var options: [CoreOption] {
        return VisualBoyAdvanceOptions.options
    }
}

extension PVVisualBoyAdvanceCore: PVGBASystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didRelease(button, forPlayer: player)
    }
}

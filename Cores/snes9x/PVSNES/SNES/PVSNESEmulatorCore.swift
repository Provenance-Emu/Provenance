//
//  PVSNESEmulatorCore.swift
//  PVSNES
//

import PVSupport
import Foundation
import PVEmulatorCore

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
open class PVSNES9xEmulatorCore: PVEmulatorCore, @unchecked Sendable {

    // MARK: Video

    // MARK: Lifecycle

    public required init() {
        super.init()
        self.bridge = (PVSNESEmulatorCoreBridge() as! any ObjCBridgedCoreBridge)
    }
}

extension PVSNES9xEmulatorCore: PVSNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (bridge as! PVSNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (bridge as! PVSNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVSNES9xEmulatorCore: ArchiveSupport {
    public var supportedArchiveFormats: ArchiveSupportOptions {
        return [.gzip, .zip]
    }
}


extension PVSNESEmulatorCoreBridge: GameWithCheat {
    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            try self.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
            return true
        } catch let error {
            NSLog("Error setCheat \(error)")
            return false
        }
    }

    public var cheatCodeTypes: [String] {
        return ["Game Genie", "Pro Action Replay", "Gold Finger", "Raw Code"]
    }

    public var supportsCheatCode: Bool
    {
        return true
    }
}

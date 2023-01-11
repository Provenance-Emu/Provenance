//
//  PVSNESEmulatorCore.swift
//  PVSNES
//

import PVSupport
import Foundation

extension PVSNESEmulatorCore: GameWithCheat {
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

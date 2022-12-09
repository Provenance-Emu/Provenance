//
//  PVSNESEmulatorCore.swift
//  PVSNES
//

import PVSupport
import Foundation

extension PVSNESEmulatorCore: GameWithCheat {
    public func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool
    {
        do {
            try self.setCheat(code, setType: type, setEnabled: enabled)
            return true
        } catch let error {
            NSLog("Error setCheat \(error)")
            return false
        }
    }
    
    public func supportsCheatCode() -> Bool
    {
        return true
    }
}

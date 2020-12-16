//
//  PVSNESEmulatorCore.swift
//  PVSNES
//

import PVSupport
import UIKit

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
}

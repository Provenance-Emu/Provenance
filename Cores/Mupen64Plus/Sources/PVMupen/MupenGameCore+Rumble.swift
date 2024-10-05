//
//  MupenGameCore+Rumble.swift
//  PVMupenGameCore
//
//  Created by Joseph Mattiello on 8/18/24.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge

@objc extension MupenGameCore { // : EmulatorCoreRumbleDataSource { // (Rumble)

    @objc public override var supportsRumble: Bool { true }
    
}

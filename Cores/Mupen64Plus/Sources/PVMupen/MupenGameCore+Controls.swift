//
//  MupenGameCore+Controls.swift
//  PVMupenGameCore
//
//  Created by Joseph Mattiello on 8/18/24.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge

public extension MupenGameCore { // Controls
    
    enum ControllerMode: UInt8 {
        /*
         #define PLUGIN_NONE                 1
         #define PLUGIN_MEMPAK               2
         #define PLUGIN_RUMBLE_PAK           3 /* not implemented for non raw data */
         #define PLUGIN_TRANSFER_PAK         4 /* not implemented for non raw data */
         #define PLUGIN_RAW                  5 /* the controller plugin is passed in raw data */
         */
        /// Auto-detect pak type from mupen64plus.ini ROM database at load time.
        /// If the ROM database marks the game as requiring a Controller Pak (Mempak),
        /// this resolves to raw/Smart Pak (5). Otherwise, if the ROM database enables
        /// rumble (Rumble=Yes), this resolves to rumblePak (3). If neither flag is set,
        /// it falls back to raw/Smart Pak (5) after M64CMD_ROM_OPEN.
        case auto = 0
        case none = 1
        case mempak = 2
        case rumblePak = 3
        case transferPak = 4
        case raw = 5
    }
    
    func setMode(_ mode: MupenGameCore.ControllerMode, forController controller: UInt) {
        self._bridge.controllerMode[controller] = mode
    }
    
}

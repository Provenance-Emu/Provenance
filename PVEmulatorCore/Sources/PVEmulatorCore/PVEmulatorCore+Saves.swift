//
//  PVEmulatorCore+Saves.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import PVLogging

@objc
extension PVEmulatorCore: EmulatorCoreSavesSerializer {
    @objc open func saveState(toFileAtPath path: String, error: NSError) -> Bool {
        return false
    }
    
    @objc open func loadState(toFileAtPath path: String, error: NSError) -> Bool {
        return false
    }
    
    @objc open func saveState(toFileAtPath fileName: String,
                   completionHandler block: SaveStateCompletion) {
        block(false, nil)
    }

    @objc open func loadState(fromFileAtPath fileName: String,
                   completionHandler block: SaveStateCompletion) {
        block(false, nil)
    }
}

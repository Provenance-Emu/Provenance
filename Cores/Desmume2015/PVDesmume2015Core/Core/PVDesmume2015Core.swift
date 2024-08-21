//
//  PVDesmume2015Core.swift
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 8/15/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibRetro
import PVLibRetroSwift
import libretro
import PVCoreBridge

@objc
@objcMembers
open class PVDesmume2015Core: PVLibRetroCore, PVDSSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        
    }
    
    public func didRelease(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        
    }
    
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler?
    
    public func didPush(_ button: Int, forPlayer player: Int) {
        
    }
    
    public func didRelease(_ button: Int, forPlayer player: Int) {
        
    }
    
    @objc open var padData : [[uint8_t]] = Array(repeating: Array(repeating: 0, count: PVDSButtonCount), count: 4)

    @objc open var _callbackQueue: dispatch_queue_t?
}

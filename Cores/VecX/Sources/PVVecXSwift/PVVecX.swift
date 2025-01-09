//
//  PVVecX.swift
//  PVVecX
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
import PVEmulatorCore
import PVVecXC
import libvecx
import PVLibRetroCore

@objc
@objcMembers
open class PVVecXGameCore: PVLibRetroCore {

    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil

    // MARK: Cheats
//    public var cheats: NSMutableArray = .init()

//    public var supportsCheatCode: Bool { true }

    // VecX
//    public var region :Region = .NTSC
//    public var _sampleRate: Double = 31400.0
//    public var _frameInterval: TimeInterval = 0
//
//    public var _videoBuffer: UnsafeMutablePointer<stellabuffer_t> = .allocate(capacity: 1)
//    public var _videoWidth: Int32 = STELLA_WIDTH
//    public var _videoHeight: Int32 = STELLA_HEIGHT

    // MARK: Lifecycle

    public required init() {
        super.init()
    }
}

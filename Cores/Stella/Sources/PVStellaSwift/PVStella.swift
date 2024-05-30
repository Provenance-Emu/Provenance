//
//  PVStella.swift
//  PVStella
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
import PVStellaCPP
import libstella

@objc public enum Region: UInt {
    case NTSC = 0
    case PAL = 1
}

@objc
@objcMembers
open class PVStellaGameCore: PVEmulatorCore {

    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil

    // MARK: Cheats
    public var cheats: NSMutableArray = .init()

    public var supportsCheatCode: Bool { true }

    // Stella
    public var region :Region = .NTSC
    public var _sampleRate: Double = 31400.0
    public var _frameInterval: TimeInterval = 0

    public var _videoBuffer: UnsafeMutablePointer<stellabuffer_t> = .allocate(capacity: 1)
    public var _videoWidth: Int32 = STELLA_WIDTH
    public var _videoHeight: Int32 = STELLA_HEIGHT

    // MARK: Lifecycle

    public required init() {
        super.init()
    }
}

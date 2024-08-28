//
//  PVStella.swift
//  PVStella
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
#if canImport(GameController)
import GameController
#endif
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
public final class PVStellaGameCore: PVEmulatorCore {

#if canImport(GameController)
    @MainActor
    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
#endif
    
    // MARK: Cheats
    @MainActor
    public let cheats: NSMutableArray = .init()

    public var supportsCheatCode: Bool { true }

    // Stella
    @MainActor
    public var region :Region = .NTSC
    @MainActor
    public var _sampleRate: Double = 31400.0
    @MainActor
    public var _frameInterval: TimeInterval = 0

    @MainActor
    public var _videoBuffer: UnsafeMutablePointer<stellabuffer_t> = .allocate(capacity: 1)
    @MainActor
    public var _videoWidth: Int32 = STELLA_WIDTH
    @MainActor
    public var _videoHeight: Int32 = STELLA_HEIGHT

    // MARK: Lifecycle

    public required init() {
        super.init()
    }
}

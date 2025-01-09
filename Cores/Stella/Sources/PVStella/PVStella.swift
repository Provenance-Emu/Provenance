//
//  PVStella.swift
//  PVStella
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVAudio
import PVEmulatorCore
import PVStellaCPP
import PVStellaBridge
import libstella
#if canImport(GameController)
import GameController
#endif

@objc public enum Region: UInt {
    case NTSC = 0
    case PAL = 1
}

@objc
@objcMembers
public final class PVStellaGameCore: PVEmulatorCore {
    
    // MARK: Cheats
//    @objc
//    public let cheats: NSMutableArray = .init()

    @objc
    public var supportsCheatCode: Bool { true }

    // Stella
    @objc
    public var region :Region = .NTSC

    @objc
    public var _sampleRate: Double = 31400.0
    @objc
    public override var audioSampleRate: Double {
        get { _sampleRate }
        set { _sampleRate = newValue }
    }
    
    @objc public override var audioBufferCount: UInt { 1 }
    @objc public override var audioBitDepth: UInt { 16 }

    // MARK: Video
    
    @objc dynamic public override var rendersToOpenGL: Bool { false }
    
//    @objc
//    public var _frameInterval: TimeInterval = 60.0
//    @objc public dynamic override var frameInterval: TimeInterval { _frameInterval  }
//    
//    @objc
//    public var _videoBuffer: UnsafeMutablePointer<stellabuffer_t> = .allocate(capacity: 1)
//    @objc
//    public override var videoBuffer: UnsafeMutableRawPointer { UnsafeMutableRawPointer.init(_videoBuffer) }
//    
//    @objc
//    public var videoWidth: Int32 { _videoWidth }
//    @objc
//    public var _videoWidth: Int32 = STELLA_WIDTH
//    @objc
//    public var videoHeight: Int32 { _videoHeight }
//    @objc
//    public var _videoHeight: Int32 = STELLA_HEIGHT

    // MARK: Lifecycle
    lazy var _bridge: PVStellaBridge = PVStellaBridge.init { key in
        self.get(variable: key)
    }

    @objc
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVStellaGameCore: PV2600SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PV2600Button, forPlayer player: Int) {
        (_bridge as! PV2600SystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PV2600Button, forPlayer player: Int) {
        (_bridge as! PV2600SystemResponderClient).didRelease(button, forPlayer: player)
    }
}

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
    
    // MARK: Cheats — GameWithCheat conformance is in PVStellaGameCore+Cheats.swift

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

    // [CHEEVOS-DIAG] Diagnostic-only frame counter so we can see when the core is
    // running frames but `achievementsActive` is false (i.e. the rc_client never
    // finished loading). Logged every 600 frames (~10 s at 60 fps).
    private static let diagLogStride: UInt64 = 600
    nonisolated(unsafe) private static var diagFrameCount: UInt64 = 0
    nonisolated(unsafe) private static var diagInactiveFrameCount: UInt64 = 0

    public override func executeFrame() {
        super.executeFrame()
        Self.diagFrameCount &+= 1
        if achievementsActive {
            tickAchievements()
        } else {
            Self.diagInactiveFrameCount &+= 1
            if Self.diagInactiveFrameCount % Self.diagLogStride == 0 {
                ILOG("[CHEEVOS-DIAG] Stella executeFrame achievementsActive=false totalFrames=\(Self.diagFrameCount) inactiveFrames=\(Self.diagInactiveFrameCount)")
            }
        }
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

//
//  PVTGBDual.swift
//  PVTGBDual
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
import PVTGBDualCPP
import libtgbdual

@objc
@objcMembers
open class PVTGBDualCore: PVEmulatorCore { //, PVGBSystemResponderClient {

    public var _videoBuffer: UnsafeMutablePointer<UInt16>? = nil // uint16_t *_videoBuffer;

    public var _videoWidth: Int = 0
    public var _videoHeight: Int = 0

    // TGBDual
    public var _sampleRate: Double = 44100.0
    public var _frameInterval: TimeInterval = 0

    public var emulationHasRun: Bool = false

//    // MARK: Lifecycle
//
//    public required init() {
//        super.init()
//    }
}

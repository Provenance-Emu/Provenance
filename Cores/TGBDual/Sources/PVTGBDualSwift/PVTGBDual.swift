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
public final class PVTGBDualCore: PVEmulatorCore { //, PVGBSystemResponderClient {

    @MainActor
    public var _videoBuffer: UnsafeMutablePointer<UInt16>? = nil // uint16_t *_videoBuffer;

    @MainActor
    public var _videoWidth: Int = 0
    @MainActor
    public var _videoHeight: Int = 0

    // TGBDual
    @MainActor
    public var _sampleRate: Double = 44100.0
    @MainActor
    public var _frameInterval: TimeInterval = 0

    @MainActor
    public var emulationHasRun: Bool = false

//    // MARK: Lifecycle
//
//    public required init() {
//        super.init()
//    }
}

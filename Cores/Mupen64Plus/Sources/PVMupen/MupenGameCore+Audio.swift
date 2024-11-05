//
//  MupenGameCore+Audio.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 1/24/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVEmulatorCore
import PVCoreBridge

@objc
public extension MupenGameCore {
    override var channelCount: UInt { 2 }
    override var audioSampleRate: Double { get { _bridge.mupenSampleRate } set {} }
    override var frameInterval: TimeInterval { _bridge.isNTSC ? 60 : 50 }
}

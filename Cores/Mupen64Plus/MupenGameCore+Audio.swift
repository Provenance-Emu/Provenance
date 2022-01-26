//
//  MupenGameCore+Audio.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 1/24/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

@objc
public extension MupenGameCore {
    override var channelCount: UInt { 2 }
    override var audioSampleRate: Double { self.mupenSampleRate }
    override var frameInterval: TimeInterval { isNTSC ? 60 : 50 }
}

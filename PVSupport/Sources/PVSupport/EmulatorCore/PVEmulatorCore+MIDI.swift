//
//  PVEmulatorCore+Microphone.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/2/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CoreMIDI

@objc public extension PVEmulatorCore {

    var midiInputEnabled: Bool { return false }
    var midiOutputEnabled: Bool { return false }

    func midiRead(_ byte: UnsafePointer<UInt8>) -> Bool {
        return false
    }

    func midiWrite(byte: UInt8, deltaTime: UInt32) -> Bool {
        return false
    }

    func midiFlush() -> Bool {
        return false
    }
}

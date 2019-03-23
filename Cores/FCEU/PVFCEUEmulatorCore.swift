//
//  PVFCEUEmulatorCore.swift
//  PVFCEU
//
//  Created by Joseph Mattiello on 3/9/18.
//  Copyright © 2018 JamSoft. All rights reserved.
//

import Foundation
import PVSupport
import FCEU

@objcMembers
@objc
public class PVFCEUEmulatorCore : PVEmulatorCore {
    let pad : [[UInt32]] = Array<Array<UInt32>>.init(repeating: Array<UInt32>(repeating: 0, count: PVNESButton.count.rawValue), count: 2)
// UInt32[2][PVSNESButton.count];

    public override var audioSampleRate: Double {
        return FSettings.SndRate
    }
}

// extension PVFCEUEmulatorCore: PVNESSystemResponderClient {
//	func didPush(_ button: PVNESButton, forPlayer player: Int) {
//
//	}
//
//	func didRelease(_ button: PVNESButton, forPlayer player: Int) {
//
//	}
// }

extension PVFCEUEmulatorCore: DiscSwappable {
    public var numberOfDiscs: UInt {
        return 2
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        return true
    }

    public func swapDisc(number: UInt) {
        internalSwapDisc(number)
    }
}

extension PVFCEUEmulatorCore: ArchiveSupport {
    public var supportedArchiveFormats: ArchiveSupportOptions {
        return [.gzip, .zip]
    }
}

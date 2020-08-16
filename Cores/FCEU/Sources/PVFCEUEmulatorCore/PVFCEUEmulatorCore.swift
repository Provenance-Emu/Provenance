//
//  PVFCEUEmulatorCore.swift
//  PVFCEU
//
//  Created by Joseph Mattiello on 3/9/18.
//  Copyright © 2018 JamSoft. All rights reserved.
//

import Foundation
import PVSupport

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

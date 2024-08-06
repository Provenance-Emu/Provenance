//
//  PVEmulatorCoreErrorCode.swift
//
//
//  Created by Joseph Mattiello on 5/19/24.
//

import Foundation

@objc
@objcMembers
public final class CoreError: NSObject {
    @objc
    static public let PVEmulatorCoreErrorDomain = "org.provenance-emu.EmulatorCore.ErrorDomain"
}

@objc
public enum PVEmulatorCoreErrorCode: NSInteger {
    static public let PVEmulatorCoreErrorDomain = "org.provenance-emu.EmulatorCore.ErrorDomain"

    case couldNotStart                  = -1
    case couldNotLoadRom                = -2
    case couldNotLoadState              = -3
    case stateHasWrongSize              = -4
    case couldNotSaveState              = -5
    case doesNotSupportSaveStates       = -6
    case missingM3U                     = -7
}

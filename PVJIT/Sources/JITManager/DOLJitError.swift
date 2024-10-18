//
//  DOLJitError.swift
//
//
//  Created by Joseph Mattiello on 6/1/24.
//

import Foundation

public
enum DOLJitError: UInt {
    case none
    case notArm64e // on NJB iOS 14.2+, need arm64e
    case improperlySigned // on NJB iOS 14.2+, need correct code directory version and flags set
    case needUpdate // iOS not supported
    case workaroundRequired // NJB iOS 14.4+ broke the JIT hack
    case gestaltFailed // an error occurred with loading MobileGestalt
    case jailbreakdFailed // an error occurred with contacting jailbreakd
    case csdbgdFailed // an error occurred with contacting csdbgd
}

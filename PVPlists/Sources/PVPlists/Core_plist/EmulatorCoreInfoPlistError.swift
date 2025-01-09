//
//  EmulatorCoreInfoPlistError.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

public enum EmulatorCoreInfoPlistError: Error {
    case missingIdentifier
    case missingPrincipleClass
    case missingSupportedSystems
    case missingProjectName
    case missingProjectURL
    case missingProjectVersion

    case couldNotReadPlist
    case couldNotParsePlist
}

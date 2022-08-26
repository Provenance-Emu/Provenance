//
//  EmulatorCore+Enums.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/25/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

@objc
public enum GameSpeed: Int {
    case slow
    case normal
    case fast
}

@objc
public enum GLESVersion: Int {
    case gles1
    case gles2
    case gles3
    case gles3_1

    #if canImport(OpenGLES)
    public var eaglRenderingAPI: EAGLRenderingAPI {
        switch self {
        case .gles1: return .openGLES1
        case .gles2: return .openGLES2
        case .gles3, .gles3_1: return .openGLES3
        }
    }
    #endif
}

@objc
public enum PVEmulatorCoreErrorCode: Int, Error {
    case couldNotStart            = -1
    case couldNotLoadRom          = -2
    case couldNotLoadState        = -3
    case stateHasWrongSize        = -4
    case couldNotSaveState        = -5
    case doesNotSupportSaveStates = -6
    case missingM3U               = -7
}

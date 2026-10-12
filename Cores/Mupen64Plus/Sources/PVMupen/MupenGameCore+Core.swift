//
//  MupenGameCore+Core.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 8/20/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation

import GameController
import PVSupport
import PVCoreBridge
import PVLogging
import PVEmulatorCore
import PVSettings
import Defaults

#if canImport(PVMupen64PlusBridge)
import PVMupen64PlusBridge   // Xcode project: the bridge is a framework of this name
#else
import PVMupenBridge         // SwiftPM package: the ObjC bridge target (m64p_* types come through its headers)
#endif

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import OpenGL.GL3
import GLUT
#elseif !os(watchOS)
import OpenGLES
import GLKit
#endif

#if os(tvOS)
let RESIZE_TO_FULLSCREEN: Bool = true
#else
let RESIZE_TO_FULLSCREEN: Bool = Defaults[.scalingMode] != .nativeResolution
#endif

extension m64p_core_param: @retroactive Hashable, @retroactive Equatable, @retroactive Codable {
    
}

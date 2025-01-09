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

#if SWIFT_MODULE
import PVMupen64PlusCore
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
let RESIZE_TO_FULLSCREEN: Bool = !Defaults[.nativeScaleEnabled]
#endif

extension m64p_core_param: @retroactive Hashable, @retroactive Equatable, @retroactive Codable {
    
}

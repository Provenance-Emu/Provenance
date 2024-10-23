//
//  MupenGameCore+Video.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 1/24/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

#if canImport(OpenGL)
import OpenGL
import GLUT
#elseif canImport(OpenGLES)
import OpenGLES.ES3
#endif

@objc public extension MupenGameCore {
#if canImport(OpenGLES) || canImport(OpenGL)
    override var rendersToOpenGL: Bool { true }
    override var pixelType: GLenum { UInt32(0x8367) }   // OpenEMU: GL_UNSIGNED_INT_8_8_8_8_REV
    override var pixelFormat: GLenum { UInt32(GL_BGRA) } // OpenEMU: GL_BGRA
    override var internalPixelFormat: GLenum { UInt32(GL_RGB8) } // OpenEMU: GL_RGB8
//    override var pixelType: GLenum { UInt32(GL_UNSIGNED_BYTE) }
//    override var pixelFormat: GLenum { UInt32(GL_BGRA) }
//    override var internalPixelFormat: GLenum { UInt32(GL_RGBA) }
#else
    override var rendersToOpenGL: Bool { false }
#endif
    override var videoBuffer: UnsafeMutableRawPointer? { nil }
    
    override var bufferSize: CGSize { .init(width: Int(_bridge.videoWidth), height: Int(_bridge.videoHeight)) }
    override var screenRect: CGRect { .init(x: 0, y: 0, width: Int(_bridge.videoWidth), height: Int(_bridge.videoHeight)) }
    override var aspectSize: CGSize { .init(width: Int(_bridge.videoWidth), height: Int(_bridge.videoHeight)) }
}

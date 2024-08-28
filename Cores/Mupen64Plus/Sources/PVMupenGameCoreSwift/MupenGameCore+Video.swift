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
    override var pixelType: GLenum { UInt32(GL_UNSIGNED_BYTE) }
    override var pixelFormat: GLenum { UInt32(GL_BGRA) }
    override var internalPixelFormat: GLenum { UInt32(GL_RGBA) }
#else
    override var rendersToOpenGL: Bool { false }
#endif
    override var videoBuffer: UnsafeMutableRawPointer? { nil }
    
    var bufferSize: CGSize { .init(width: 1024, height: 512) }
    override var screenRect: CGRect { .init(x: 0, y: 0, width: Int(videoWidth), height: Int(videoHeight)) }
    override var aspectSize: CGSize { .init(width: Int(videoWidth), height: Int(videoHeight)) }
}

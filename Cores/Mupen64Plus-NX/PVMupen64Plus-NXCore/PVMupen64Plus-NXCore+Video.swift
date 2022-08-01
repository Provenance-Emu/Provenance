//
//  MupenGameNXCore+Audio.swift
//  PVMupen64Plus-NX
//
//  Created by Joseph Mattiello on 1/24/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

#if targetEnvironment(macCatalyst)
import OpenGL
import GLUT
#else
import OpenGLES.ES3
#endif

@objc
public extension PVMupen64PlusNXCore {
    override var rendersToOpenGL: Bool { true }
    override var pixelType: GLenum { UInt32(GL_UNSIGNED_BYTE) }
    override var pixelFormat: GLenum { UInt32(GL_BGRA) }
    override var internalPixelFormat: GLenum { UInt32(GL_RGBA) }
    override var videoBuffer: UnsafeRawPointer? { nil }
    
    override var bufferSize: CGSize { .init(width: 1024, height: 512) }
    override var screenRect: CGRect { .init(x: 0, y: 0, width: Int(videoWidth), height: Int(videoHeight)) }
    override var aspectSize: CGSize { .init(width: Int(videoWidth), height: Int(videoHeight)) }
}

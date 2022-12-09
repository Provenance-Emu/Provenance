// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
#if os(macOS)
import OpenGL
typealias GLContext = CGLContextObj
#else
import OpenGLES
typealias GLContext = EAGLContext
#endif
import CoreVideo

// source: https://developer.apple.com/documentation/metal/mixing_metal_and_opengl_rendering_in_a_view

final class CoreVideoTexture {
    let formatInfo: TextureFormatInfo
    let metalDevice: MTLDevice
    
    public init(device: MTLDevice, metalPixelFormat mtlPixelFormat: MTLPixelFormat) {
        guard let tfi = Self.textureFormatInfoFromMetalPixelFormat(mtlPixelFormat) else {
            fatalError("Unsupported Metal pixel format")
        }
        
        self.formatInfo = tfi
        self.metalDevice    = device
    }
    
    var cvPixelBuffer: CVPixelBuffer?
    
    var size: CGSize = .zero {
        didSet {
            let cvBufferProperties = [
                kCVPixelBufferOpenGLCompatibilityKey: true,
                kCVPixelBufferMetalCompatibilityKey: true,
            ]
            
            guard CVPixelBufferCreate(kCFAllocatorDefault,
                                      Int(size.width), Int(size.height),
                                      formatInfo.cvPixelFormat,
                                      cvBufferProperties as CFDictionary, &cvPixelBuffer) == kCVReturnSuccess
            else {
                fatalError("Failed to create CVPixelBuffer")
            }
            
            if let openGLContext = openGLContext {
                createGLTexture(context: openGLContext)
            }
            
            createMetalTexture(device: metalDevice)
        }
    }
    
    // MARK: - Metal resources
    
    var metalTexture: MTLTexture?
    
    var cvMTLTextureCache: CVMetalTextureCache?
    var cvMTLTexture: CVMetalTexture?
    
    private func releaseMetalTexture() {
        metalTexture        = nil
        cvMTLTexture        = nil
        cvMTLTextureCache   = nil
    }
    
    private func createMetalTexture(device: MTLDevice) {
        releaseMetalTexture()
        guard size != .zero else { return }
        
        // 1. Create a Metal Core Video texture cache from the pixel buffer.
        guard
            CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                      nil,
                                      device,
                                      nil,
                                      &cvMTLTextureCache) == kCVReturnSuccess
        else { return }
        
        // 2. Create a CoreVideo pixel buffer backed Metal texture image from the texture cache.
        guard
            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                      cvMTLTextureCache!,
                                                      cvPixelBuffer!,
                                                      nil,
                                                      formatInfo.mtlFormat,
                                                      Int(size.width),
                                                      Int(size.height),
                                                      0,
                                                      &cvMTLTexture) == kCVReturnSuccess
        else {
            fatalError("Failed to create Metal texture cache")
        }
        
        // 3. Get a Metal texture using the CoreVideo Metal texture reference.
        metalTexture = CVMetalTextureGetTexture(cvMTLTexture!)
        guard
            metalTexture != nil
        else {
            fatalError("Failed to get Metal texture from CVMetalTexture")
        }
    }
    
    var metalTextureIsFlippedVertically: Bool {
        if let cvMTLTexture = cvMTLTexture {
            return CVMetalTextureIsFlipped(cvMTLTexture)
        }
        return false
    }
    
    // MARK: - OpenGL resources
    
    var openGLContext: GLContext? {
        didSet {
            if let openGLContext = openGLContext {
#if os(macOS)
                cglPixelFormat = CGLGetPixelFormat(openGLContext)
#endif
                createGLTexture(context: openGLContext)
            }
        }
    }
    var openGLTexture: GLuint = 0
    
#if os(macOS)
    var cvGLTextureCache: CVOpenGLTextureCache?
    var cvGLTexture: CVOpenGLTexture?
    var cglPixelFormat: CGLPixelFormatObj?
#else
    var cvGLTextureCache: CVOpenGLESTextureCache?
    var cvGLTexture: CVOpenGLESTexture?
#endif
    
    private func releaseGLTexture() {
        openGLTexture       = 0
        cvGLTexture         = nil
        cvGLTextureCache    = nil
    }
    
#if os(macOS)
    private func createGLTexture(context: GLContext) {
        releaseGLTexture()
        
        guard size != .zero else { return }

        // 1. Create an OpenGL CoreVideo texture cache from the pixel buffer.
        guard
            CVOpenGLTextureCacheCreate(kCFAllocatorDefault,
                                       nil,
                                       context,
                                       cglPixelFormat!,
                                       nil,
                                       &cvGLTextureCache) == kCVReturnSuccess
        else {
            fatalError("Failed to create OpenGL texture cache")
        }
        
        // 2. Create a CVPixelBuffer-backed OpenGL texture image from the texture cache.
        guard
            CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       cvGLTextureCache!,
                                                       cvPixelBuffer!,
                                                       nil,
                                                       &cvGLTexture) == kCVReturnSuccess
        else {
            fatalError("Failed to create OpenGL texture from image")
        }
        
        // 3. Get an OpenGL texture name from the CVPixelBuffer-backed OpenGL texture image.
        openGLTexture = CVOpenGLTextureGetName(cvGLTexture!)
    }
#else
    private func createGLTexture(context: GLContext) {
        releaseGLTexture()
        
        guard size != .zero else { return }

        // 1. Create an OpenGL CoreVideo texture cache from the pixel buffer.
        guard
            CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                         nil,
                                         context,
                                         nil, &cvGLTextureCache) == kCVReturnSuccess
        else {
            fatalError("Failed to create OpenGLES texture cache")
        }
        
        // 2. Create a CVPixelBuffer-backed OpenGL texture image from the texture cache.
        guard
            CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         cvGLTextureCache!,
                                                         cvPixelBuffer!,
                                                         nil,
                                                         GLenum(bitPattern: GL_TEXTURE_2D),
                                                         formatInfo.glInternalFormat,
                                                         GLsizei(size.width), GLsizei(size.height),
                                                         formatInfo.glFormat,
                                                         formatInfo.glType,
                                                         0,
                                                         &cvGLTexture) == kCVReturnSuccess
        else {
            fatalError("Failed to create OpenGL texture from image")
        }
        
        // 3. Get an OpenGL texture name from the CVPixelBuffer-backed OpenGL texture image.
        openGLTexture = CVOpenGLESTextureGetName(cvGLTexture!)
    }

#endif
    
    // MARK: - Static helpers
    
    // source: https://developer.apple.com/documentation/metal/mixing_metal_and_opengl_rendering_in_a_view
    
    struct TextureFormatInfo {
        let cvPixelFormat: OSType
        let mtlFormat: MTLPixelFormat
        let glInternalFormat: GLint
        let glFormat: GLenum
        let glType: GLenum
    }
    
    #if !os(macOS)
    static let GL_UNSIGNED_INT_8_8_8_8_REV: GLenum = 0x8367
    #endif

    #if os(macOS)
    private static let interopFormatTable: [TextureFormatInfo] = [
        .init(cvPixelFormat: kCVPixelFormatType_32BGRA, mtlFormat: .bgra8Unorm, glInternalFormat: GL_RGBA, glFormat: GLenum(bitPattern: GL_BGRA_EXT), glType: GL_UNSIGNED_INT_8_8_8_8_REV),
        .init(cvPixelFormat: kCVPixelFormatType_ARGB2101010LEPacked, mtlFormat: .bgr10a2Unorm, glInternalFormat: GL_RGB10_A2, glFormat: GLenum(bitPattern: GL_BGRA), glType: GL_UNSIGNED_INT_2_10_10_10_REV)
        .init(cvPixelFormat: kCVPixelFormatType_32BGRA, mtlFormat: .bgra8Unorm_srgb, glInternalFormat: GL_SRGB8_ALPHA8, glFormat: GLenum(bitPattern: GL_BGRA), glType: GL_UNSIGNED_INT_8_8_8_8_REV)
        .init(cvPixelFormat: kCVPixelFormatType_64RGBAHalf, mtlFormat: .rgba16Float, glInternalFormat: GL_RGBA, glFormat: GLenum(bitPattern: GL_RGBA), glType: GL_HALF_FLOAT)
    ]
    #else
    private static let interopFormatTable: [TextureFormatInfo] = [
        .init(cvPixelFormat: kCVPixelFormatType_32BGRA, mtlFormat: .bgra8Unorm, glInternalFormat: GL_RGBA, glFormat: GLenum(bitPattern: GL_BGRA_EXT), glType: GL_UNSIGNED_INT_8_8_8_8_REV),
        .init(cvPixelFormat: kCVPixelFormatType_32BGRA, mtlFormat: .bgra8Unorm_srgb, glInternalFormat: GL_RGBA, glFormat: GLenum(bitPattern: GL_BGRA_EXT), glType: GL_UNSIGNED_INT_8_8_8_8_REV),
    ]
    #endif
    
    private static func textureFormatInfoFromMetalPixelFormat(_ format: MTLPixelFormat) -> TextureFormatInfo? {
        interopFormatTable.first { $0.mtlFormat == format }
    }
}

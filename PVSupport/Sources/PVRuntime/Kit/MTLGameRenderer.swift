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
import OpenEmuShaders
import Metal
#if os(macOS)
import OpenGL
#else
import OpenGLES
#endif

final class MTLGameRenderer: GameRenderer {
    var surfaceSize: OEIntSize { gameCore.bufferSize }
    let gameCore: OEGameCore
    private(set) var renderTexture: MTLTexture?
    
    private let device: MTLDevice
    private let converter: MTLPixelConverter
    private var buffer: PixelBuffer!
    private var texture: MTLTexture!
    
    init(withDevice device: MTLDevice, gameCore: OEGameCore) throws {
        self.device      = device
        self.converter   = try .init(device: device)
        self.gameCore    = gameCore
    }
    
    func update() {
        precondition(gameCore.gameCoreRendering == .rendering2DVideo, "Metal only supports 2D rendering")

        let pixelFormat = gameCore.pixelFormat
        let pixelType   = gameCore.pixelType
        guard let pf = glToRPixelFormat(pixelFormat: pixelFormat, pixelType: pixelType) else {
            fatalError("Invalid pixel format")
        }

        // bufferSize is fixed for 2D, so doesn't need to be reallocated.
        if buffer == nil {
            let bufferSize  = gameCore.bufferSize
            let bytesPerRow = gameCore.bytesPerRow

            buffer = PixelBuffer.makeBuffer(withDevice: device,
                    converter: converter,
                    format: pf,
                    height: Int(bufferSize.height),
                    bytesPerRow: bytesPerRow)

            let buf = UnsafeMutableRawPointer(mutating: gameCore.getVideoBuffer(withHint: buffer.contents))
            if buf != buffer.contents {
                buffer = PixelBuffer.makeBuffer(withDevice: device,
                        converter: converter,
                        format: pf,
                        height: Int(bufferSize.height),
                        bytesPerRow: bytesPerRow,
                        bytes: buf)
            }
        }

        guard let buffer = buffer else {
            fatalError("buffer == nil")
        }

        let rect       = gameCore.screenRect
        let sourceRect = CGRect(x: CGFloat(rect.origin.x), y: CGFloat(rect.origin.y),
                width: CGFloat(rect.size.width), height: CGFloat(rect.size.height))
        buffer.outputRect = sourceRect

        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                width: Int(sourceRect.width),
                height: Int(sourceRect.height),
                mipmapped: false)
        td.storageMode = .private
        td.usage = [.shaderRead, .shaderWrite]
        renderTexture = device.makeTexture(descriptor: td)
    }

    var canChangeBufferSize: Bool { true }
    
    func willExecuteFrame() {
        assert(buffer.contents == UnsafeMutableRawPointer(mutating: gameCore.getVideoBuffer(withHint: buffer.contents)),
               "Game suddenly stopped using direct rendering")
    }
    
    func didExecuteFrame() { }
    
    func prepareFrameForRender(commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let renderTexture = renderTexture else {
            return nil
        }
        buffer.prepare(withCommandBuffer: commandBuffer, texture: renderTexture)
        return renderTexture
    }
    
    func suspendFPSLimiting() { }
    func resumeFPSLimiting() { }
    
    private func glToRPixelFormat(pixelFormat: GLenum, pixelType: GLenum) -> OEMTLPixelFormat? {
        switch Int32(pixelFormat) {
        case GL_BGRA:
#if os(macOS)
            if Int32(pixelType) == GL_UNSIGNED_INT_8_8_8_8_REV {
                return .bgra8Unorm
            }
#endif
            
        case GL_RGB:
            if Int32(pixelType) == GL_UNSIGNED_SHORT_5_6_5 {
                return .b5g6r5Unorm
            }
            
        case GL_RGBA:
            switch Int32(pixelType) {
#if os(macOS)
            case GL_UNSIGNED_INT_8_8_8_8_REV:
                return .abgr8Unorm
            case GL_UNSIGNED_INT_8_8_8_8:
                return .rgba8Unorm
#endif
            case GL_UNSIGNED_SHORT_1_5_5_5_REV:
                return .r5g5b5a1Unorm
            default:
                break
            }
        default:
            break
        }
        
        return nil
    }
}

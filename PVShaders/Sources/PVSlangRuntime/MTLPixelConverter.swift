// Copyright (c) 2019, OpenEmu Team
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
import Metal
import simd

public class MTLPixelConverter {
    enum Error: LocalizedError {
        case missingFunction(String)
    }

    @frozen @usableFromInline struct BufferUniforms {
        let origin: SIMD2<UInt32>
        let stride: UInt32
    }

    public class BufferConverter {
        let kernel: MTLComputePipelineState
        let bytesPerPixel: Int

        init(kernel: MTLComputePipelineState, bytesPerPixel: Int) {
            self.kernel = kernel
            self.bytesPerPixel = bytesPerPixel
        }

        public func convert(
            fromBuffer src: MTLBuffer,
            sourceOrigin: MTLOrigin,
            sourceBytesPerRow: Int,
            toTexture dst: MTLTexture,
            commandBuffer: MTLCommandBuffer
        ) {
            let ce = commandBuffer.makeComputeCommandEncoder()!
            ce.label = "pixel conversion"
            ce.setComputePipelineState(kernel)

            var unif = BufferUniforms(
                origin: SIMD2(x: UInt32(sourceOrigin.x), y: UInt32(sourceOrigin.y)),
                stride: UInt32(sourceBytesPerRow / bytesPerPixel)
            )

            ce.setBuffer(src, offset: 0, index: 0)
            ce.setBytes(&unif, length: MemoryLayout.stride(ofValue: unif), index: 1)
            ce.setTexture(dst, index: 0)

            let size = MTLSizeMake(16, 16, 1)
            let count = MTLSizeMake(
                (dst.width + size.width + 1) / size.width,
                (dst.height + size.height + 1) / size.height,
                1
            )
            ce.dispatchThreadgroups(count, threadsPerThreadgroup: size)
            ce.endEncoding()
        }
    }

    public class TextureConverter {
        let kernel: MTLComputePipelineState

        init(kernel: MTLComputePipelineState) {
            self.kernel = kernel
        }

        public func convert(texture src: MTLTexture, out dst: MTLTexture, commandBuffer: MTLCommandBuffer) {
            let ce = commandBuffer.makeComputeCommandEncoder()!
            ce.label = "pixel conversion"
            ce.setComputePipelineState(kernel)

            ce.setTextures([src, dst], range: 0 ..< 2)

            let size = MTLSizeMake(16, 16, 1)
            let count = MTLSizeMake(
                (src.width + size.width + 1) / size.width,
                (src.height + size.height + 1) / size.height,
                1
            )
            ce.dispatchThreadgroups(count, threadsPerThreadgroup: size)
            ce.endEncoding()
        }
    }

    let texToTex: [TextureConverter?]
    let bufToTex: [BufferConverter?]

    enum ConverterType {
        case fromBuffer, fromTexture
    }

    nonisolated(unsafe) static let converters: [(ConverterType, OEMTLPixelFormat, String)] = [
        (.fromTexture, .bgra4Unorm, "convert_bgra4444_to_bgra8888"),
        (.fromTexture, .b5g6r5Unorm, "convert_rgb565_to_bgra8888"),

        (.fromBuffer, .bgra4Unorm, "convert_bgra4444_to_bgra8888_buf"),
        (.fromBuffer, .b5g6r5Unorm, "convert_rgb565_to_bgra8888_buf"),
        (.fromBuffer, .r5g5b5a1Unorm, "convert_bgra5551_to_bgra8888_buf"),
        (.fromBuffer, .rgba8Unorm, "convert_rgba8888_to_bgra8888_buf"),
        (.fromBuffer, .abgr8Unorm, "convert_abgr8888_to_bgra8888_buf"),
    ]

    public init(device: MTLDevice) throws {
        let library = try RuntimeLibrary.library(for: device, source: .converters)

        var texToTex = [TextureConverter?](repeating: nil, count: OEMTLPixelFormat.allCases.count)
        var bufToTex = [BufferConverter?](repeating: nil, count: OEMTLPixelFormat.allCases.count)

        for (source, format, name) in MTLPixelConverter.converters {
            guard let fn = library.makeFunction(name: name) else {
                throw Error.missingFunction(name)
            }

            let kernel = try device.makeComputePipelineState(function: fn)

            switch source {
            case .fromBuffer:
                bufToTex[format.rawValue] = BufferConverter(kernel: kernel, bytesPerPixel: format.bytesPerPixel)
            case .fromTexture:
                texToTex[format.rawValue] = TextureConverter(kernel: kernel)
            }
        }
        self.texToTex = texToTex
        self.bufToTex = bufToTex
    }

    public func convert(
        fromBuffer src: MTLBuffer,
        sourceFormat: OEMTLPixelFormat,
        sourceOrigin: MTLOrigin,
        sourceBytesPerRow: Int,
        toTexture dst: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        guard let filter = bufToTex[sourceFormat.rawValue] else {
            return
        }
        filter.convert(
            fromBuffer: src,
            sourceOrigin: sourceOrigin,
            sourceBytesPerRow: sourceBytesPerRow,
            toTexture: dst,
            commandBuffer: commandBuffer
        )
    }

    public func bufferConverter(withFormat sourceFormat: OEMTLPixelFormat) -> BufferConverter? {
        bufToTex[sourceFormat.rawValue]
    }

    public func textureConverter(withFormat sourceFormat: OEMTLPixelFormat) -> TextureConverter? {
        texToTex[sourceFormat.rawValue]
    }

    public func convert(
        fromTexture src: MTLTexture,
        sourceFormat: OEMTLPixelFormat,
        toTexture dst: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        guard let filter = texToTex[sourceFormat.rawValue] else {
            return
        }
        filter.convert(texture: src, out: dst, commandBuffer: commandBuffer)
    }
}

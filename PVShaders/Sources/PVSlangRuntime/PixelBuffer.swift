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
import Metal

public class PixelBuffer {
    let device: MTLDevice
    public let format: OEMTLPixelFormat
    let bpp: Int // bytes per pixel

    let sourceBytesPerRow: Int
    let sourceBuffer: MTLBuffer
    public let sourceSize: CGSize
    public var outputRect: CGRect = .zero {
        didSet {
            // short copy if the buffer > 1MB and were copying < 50% of the buffer.
            shortCopy = bufferLenBytes > 1_000_000 && Int(outputRect.width) * bpp * Int(outputRect.height) <=
                bufferLenBytes / 2
        }
    }

    public let contents: UnsafeMutableRawPointer

    // for unaligned buffers
    let buffer: UnsafeMutableRawPointer
    let bufferLenBytes: Int
    let bufferFree: Bool
    var shortCopy: Bool = false

    // swiftformat:disable consecutiveSpaces redundantSelf
    private init(
        withDevice device: MTLDevice,
        format: OEMTLPixelFormat,
        height: Int,
        bytesPerRow: Int,
        pointer: UnsafeMutableRawPointer?
    ) {
        let length = height * bytesPerRow

        self.device             = device
        self.format             = format
        self.bpp                = format.bytesPerPixel
        self.sourceBytesPerRow  = bytesPerRow
        self.sourceSize         = .init(width: bytesPerRow / bpp, height: height)
        self.bufferLenBytes     = length
        self.sourceBuffer       = device.makeBuffer(length: length, options: .storageModeShared)!

        if let pointer {
            buffer      = pointer
            bufferFree  = false
        } else {
            buffer      = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: 256)
            bufferFree  = true
        }

        contents = buffer
    }

    // swiftformat:enable all

    deinit {
        if bufferFree {
            buffer.deallocate()
        }
    }

    func copyBuffer() {
        if shortCopy {
            var src = buffer
            var dst = sourceBuffer.contents()
            let rowLen = Int(outputRect.width) * bpp

            if outputRect.origin != .zero {
                let offset = (Int(outputRect.origin.y) * sourceBytesPerRow) + (Int(outputRect.origin.x) * bpp)
                src += offset
                dst += offset
            }

            for _ in 0 ..< Int(outputRect.height) {
                dst.copyMemory(from: src, byteCount: rowLen)
                src += sourceBytesPerRow
                dst += sourceBytesPerRow
            }
        } else {
            sourceBuffer.contents().copyMemory(from: buffer, byteCount: bufferLenBytes)
        }
    }

    // MARK: - Internal APIs

    public func prepare(withCommandBuffer _: MTLCommandBuffer, texture _: MTLTexture) {
        fatalError("not implemented")
    }

    // MARK: - Static initializers

    public static func makeBuffer(
        withDevice device: MTLDevice,
        converter: MTLPixelConverter,
        format: OEMTLPixelFormat,
        height: Int,
        bytesPerRow: Int
    ) -> PixelBuffer {
        makeBuffer(
            withDevice: device,
            converter: converter,
            format: format,
            height: height,
            bytesPerRow: bytesPerRow,
            bytes: nil
        )
    }

    public static func makeBuffer(
        withDevice device: MTLDevice,
        converter: MTLPixelConverter,
        format: OEMTLPixelFormat,
        height: Int,
        bytesPerRow: Int,
        bytes: UnsafeMutableRawPointer?
    ) -> PixelBuffer {
        if format.isNative {
            return NativePixelBuffer(
                withDevice: device,
                format: format,
                height: height,
                bytesPerRow: bytesPerRow,
                pointer: bytes
            )
        }

        guard let conv = converter.bufferConverter(withFormat: format) else { fatalError("Unable to create converter") }

        return IntermediatePixelBuffer(
            withDevice: device,
            converter: conv,
            format: format,
            height: height,
            bytesPerRow: bytesPerRow,
            pointer: bytes
        )
    }

    // MARK: - Class cluster

    class NativePixelBuffer: PixelBuffer {
        override init(
            withDevice device: MTLDevice,
            format: OEMTLPixelFormat,
            height: Int,
            bytesPerRow: Int,
            pointer: UnsafeMutableRawPointer?
        ) {
            super.init(withDevice: device, format: format, height: height, bytesPerRow: bytesPerRow, pointer: pointer)
        }

        override func prepare(withCommandBuffer commandBuffer: MTLCommandBuffer, texture: MTLTexture) {
            if texture.storageMode != .private {
                texture.replace(
                    region: MTLRegionMake2D(
                        Int(outputRect.origin.x),
                        Int(outputRect.origin.y),
                        Int(outputRect.width),
                        Int(outputRect.height)
                    ),
                    mipmapLevel: 0,
                    withBytes: buffer,
                    bytesPerRow: sourceBytesPerRow
                )
                return
            }

            copyBuffer()

            let size = MTLSize(width: Int(outputRect.width), height: Int(outputRect.height), depth: 1)
            if let bce = commandBuffer.makeBlitCommandEncoder() {
                let offset = (Int(outputRect.origin.y) * sourceBytesPerRow) + Int(outputRect.origin.x) * 4 // 4 bpp
                let len = sourceBuffer.length - (Int(outputRect.origin.y) * sourceBytesPerRow)
                bce.copy(
                    from: sourceBuffer,
                    sourceOffset: offset,
                    sourceBytesPerRow: sourceBytesPerRow,
                    sourceBytesPerImage: len,
                    sourceSize: size,
                    to: texture,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: .init()
                )
                bce.endEncoding()
            }
        }
    }

    class IntermediatePixelBuffer: PixelBuffer {
        let converter: MTLPixelConverter.BufferConverter

        init(
            withDevice device: MTLDevice,
            converter: MTLPixelConverter.BufferConverter,
            format: OEMTLPixelFormat,
            height: Int,
            bytesPerRow: Int,
            pointer: UnsafeMutableRawPointer?
        ) {
            self.converter = converter
            super.init(withDevice: device, format: format, height: height, bytesPerRow: bytesPerRow, pointer: pointer)
        }

        override func prepare(withCommandBuffer commandBuffer: MTLCommandBuffer, texture: MTLTexture) {
            copyBuffer()

            let orig = MTLOrigin(x: Int(outputRect.origin.x), y: Int(outputRect.origin.y), z: 0)
            converter.convert(
                fromBuffer: sourceBuffer,
                sourceOrigin: orig,
                sourceBytesPerRow: sourceBytesPerRow,
                toTexture: texture,
                commandBuffer: commandBuffer
            )
        }
    }
}

public enum OEMTLPixelFormat: Int, CaseIterable {
    // 16-bit formats
    case bgra4Unorm
    case b5g6r5Unorm
    case r5g5b5a1Unorm

    // 32-bit formats, 8 bits per pixel
    case rgba8Unorm
    case abgr8Unorm

    // native, no conversion
    case bgra8Unorm
    case bgrx8Unorm // no alpha

    var isNative: Bool {
        switch self {
        case .abgr8Unorm, .rgba8Unorm, .r5g5b5a1Unorm, .b5g6r5Unorm, .bgra4Unorm:
            false

        case .bgra8Unorm, .bgrx8Unorm:
            true
        }
    }

    /// Returns the number of bytes per pixel for the given format; otherwise, 0 if the format is not supported
    var bytesPerPixel: Int {
        switch self {
        case .abgr8Unorm, .rgba8Unorm, .bgra8Unorm, .bgrx8Unorm:
            4

        case .b5g6r5Unorm, .r5g5b5a1Unorm, .bgra4Unorm:
            2
        }
    }
}

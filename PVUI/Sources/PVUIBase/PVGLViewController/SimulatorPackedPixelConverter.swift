//
//  SimulatorPackedPixelConverter.swift
//  PVUIBase
//

#if targetEnvironment(simulator)
import Metal

/// The simulator's Metal device has no packed 16-bit texture formats: creating one fails with
/// "pixelFormat (40) is not a valid MTLPixelFormat". Cores that output them (native Snes9x is
/// RGB565) are drawn there through an RGBA8 texture, and this expands each frame to match.
/// Devices upload those frames as they are.
enum SimulatorPackedPixelConverter {
    static let outputFormat: MTLPixelFormat = .rgba8Unorm
    static let outputBytesPerPixel = 4

    private static let sourceBytesPerPixel = MemoryLayout<UInt16>.size

    static func needsConversion(_ format: MTLPixelFormat) -> Bool {
        switch format {
        case .b5g6r5Unorm, .a1bgr5Unorm, .abgr4Unorm, .bgr5A1Unorm: return true
        default: return false
        }
    }

    /// The texture format the simulator can create for a core that outputs `format`.
    static func textureFormat(for format: MTLPixelFormat) -> MTLPixelFormat {
        needsConversion(format) ? outputFormat : format
    }

    /// One packed pixel as RGBA8. Metal names packed components from the least significant bit up.
    static func rgba(_ pixel: UInt16, format: MTLPixelFormat) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        switch format {
        case .b5g6r5Unorm:
            return (expand5(pixel >> 11), expand6(pixel >> 5), expand5(pixel), .max)
        case .a1bgr5Unorm:
            return (expand5(pixel >> 11), expand5(pixel >> 6), expand5(pixel >> 1), pixel & 0x1 == 0 ? 0 : .max)
        case .bgr5A1Unorm:
            return (expand5(pixel >> 10), expand5(pixel >> 5), expand5(pixel), pixel & 0x8000 == 0 ? 0 : .max)
        case .abgr4Unorm:
            return (expand4(pixel >> 12), expand4(pixel >> 8), expand4(pixel >> 4), expand4(pixel))
        default:
            return (0, 0, 0, .max)
        }
    }

    /// Expands `width` x `height` packed pixels, whose rows are `sourceBytesPerRow` apart, into
    /// tightly packed RGBA8 rows in `destination`.
    static func convert(_ source: UnsafeRawPointer, sourceBytesPerRow: Int, width: Int, height: Int,
                        format: MTLPixelFormat, into destination: inout [UInt8]) {
        let byteCount = width * height * outputBytesPerPixel
        if destination.count != byteCount {
            destination = [UInt8](repeating: 0, count: byteCount)
        }
        destination.withUnsafeMutableBufferPointer { output in
            var written = 0
            for row in 0..<height {
                let rowStart = source.advanced(by: row * sourceBytesPerRow)
                for column in 0..<width {
                    let pixel = rowStart.loadUnaligned(fromByteOffset: column * sourceBytesPerPixel, as: UInt16.self)
                    let color = rgba(pixel, format: format)
                    output[written] = color.red
                    output[written + 1] = color.green
                    output[written + 2] = color.blue
                    output[written + 3] = color.alpha
                    written += outputBytesPerPixel
                }
            }
        }
    }

    private static func expand5(_ value: UInt16) -> UInt8 {
        let bits = value & 0x1F
        return UInt8((bits << 3) | (bits >> 2))
    }

    private static func expand6(_ value: UInt16) -> UInt8 {
        let bits = value & 0x3F
        return UInt8((bits << 2) | (bits >> 4))
    }

    private static func expand4(_ value: UInt16) -> UInt8 {
        let bits = value & 0xF
        return UInt8((bits << 4) | bits)
    }
}
#endif

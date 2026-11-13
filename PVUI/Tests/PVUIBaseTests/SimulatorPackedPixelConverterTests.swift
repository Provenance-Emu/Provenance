//
//  SimulatorPackedPixelConverterTests.swift
//  PVUIBaseTests
//

#if targetEnvironment(simulator)
import Metal
import Testing
@testable import PVUIBase

@Suite("SimulatorPackedPixelConverter")
struct SimulatorPackedPixelConverterTests {
    private func components(_ pixel: UInt16, _ format: MTLPixelFormat) -> [UInt8] {
        let color = SimulatorPackedPixelConverter.rgba(pixel, format: format)
        return [color.red, color.green, color.blue, color.alpha]
    }

    @Test func packedFormatsAreDrawnThroughRGBA8() {
        #expect(SimulatorPackedPixelConverter.textureFormat(for: .b5g6r5Unorm) == .rgba8Unorm)
        #expect(SimulatorPackedPixelConverter.textureFormat(for: .a1bgr5Unorm) == .rgba8Unorm)
        #expect(SimulatorPackedPixelConverter.textureFormat(for: .abgr4Unorm) == .rgba8Unorm)
    }

    /// FCEU and Genesis Plus GX output BGRA; forcing RGBA8 on them swapped red and blue.
    @Test func otherFormatsKeepTheCoreFormat() {
        #expect(SimulatorPackedPixelConverter.textureFormat(for: .bgra8Unorm) == .bgra8Unorm)
        #expect(SimulatorPackedPixelConverter.textureFormat(for: .rgba8Unorm) == .rgba8Unorm)
    }

    @Test func rgb565PrimariesExpandToFullRange() {
        let format = MTLPixelFormat.b5g6r5Unorm
        #expect(components(0xFFFF, format) == [255, 255, 255, 255])
        #expect(components(0xF800, format) == [255, 0, 0, 255])
        #expect(components(0x07E0, format) == [0, 255, 0, 255])
        #expect(components(0x001F, format) == [0, 0, 255, 255])
        #expect(components(0x0000, format) == [0, 0, 0, 255])
    }

    @Test func rgba5551ReadsAlphaFromTheLowBit() {
        let format = MTLPixelFormat.a1bgr5Unorm
        #expect(components(0xF801, format) == [255, 0, 0, 255])
        #expect(components(0x003E, format) == [0, 0, 255, 0])
    }

    @Test func rgba4444ExpandsEachNibble() {
        #expect(components(0xF0A5, .abgr4Unorm) == [255, 0, 170, 85])
    }

    /// Snes9x rows are 512 pixels apart while the picture is 256 wide: the pixels after the
    /// picture in each row must not reach the texture.
    @Test func convertSkipsTheRowPadding() throws {
        let width = 2, height = 2, rowPixels = 4
        var source = [UInt16](repeating: 0x07E0, count: rowPixels * height)
        source[0] = 0xF800
        source[1] = 0x001F
        source[rowPixels] = 0xFFFF
        source[rowPixels + 1] = 0x0000

        var output: [UInt8] = []
        try source.withUnsafeBytes { bytes in
            let base = try #require(bytes.baseAddress)
            SimulatorPackedPixelConverter.convert(base, sourceBytesPerRow: rowPixels * MemoryLayout<UInt16>.size,
                                                  width: width, height: height, format: .b5g6r5Unorm, into: &output)
        }

        #expect(output == [
            255, 0, 0, 255, 0, 0, 255, 255,
            255, 255, 255, 255, 0, 0, 0, 255
        ])
    }
}
#endif

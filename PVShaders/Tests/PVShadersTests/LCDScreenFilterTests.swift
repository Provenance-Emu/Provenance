//
//  LCDScreenFilterTests.swift
//  PVShadersTests
//

import CoreGraphics
import CoreImage
import Testing
@testable import PVShaders

@Suite("LCDScreenFilter")
struct LCDScreenFilterTests {
    private static let size = 48
    private static let pitch: CGFloat = 8

    /// Renders the filter over flat grey and returns one row of red values.
    private func row(_ y: Int, gridStrength: CGFloat) throws -> [UInt8] {
        let grey = CIImage(color: CIColor(red: 0.6, green: 0.6, blue: 0.6))
            .cropped(to: CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        let filter = LCDScreenFilter()
        filter.inputImage = grey
        filter.inputPixelPitch = Self.pitch
        filter.inputGridStrength = gridStrength
        filter.inputGhosting = 0
        filter.inputSaturation = 1
        filter.inputBrightness = 0
        let output = try #require(filter.outputImage)
        #expect(output.extent == grey.extent)
        var bytes = [UInt8](repeating: 0, count: Self.size * 4)
        CIContext().render(output, toBitmap: &bytes, rowBytes: Self.size * 4,
                           bounds: CGRect(x: 0, y: y, width: Self.size, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] }
    }

    @Test("gaps between emulated pixels are darker than the pixels")
    func drawsGrid() throws {
        let values = try row(2, gridStrength: 0.5)
        let darkest = try #require(values.min())
        let brightest = try #require(values.max())
        #expect(Int(brightest) - Int(darkest) > 40)
        // One gap per emulated pixel along the row.
        let gaps = values.indices.filter { values[$0] < brightest && ($0 == 0 || values[$0 - 1] == brightest) }
        #expect(gaps.count == Self.size / Int(Self.pitch))
    }

    @Test("zero grid strength leaves a flat image flat")
    func noGrid() throws {
        let values = try row(2, gridStrength: 0)
        #expect(Set(values).count == 1)
    }
}

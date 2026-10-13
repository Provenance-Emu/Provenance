//
//  FrameImageFilterTests.swift
//  PVShadersTests
//

import CoreGraphics
import CoreImage
import Testing
@testable import PVShaders

@Suite("FrameImageFilter")
struct FrameImageFilterTests {
    private static let extent = CGRect(x: 0, y: 0, width: 8, height: 8)

    /// A directional effect: paints the upper half (Core Image's y grows upwards) white.
    private static func paintUpperHalf(_ image: CIImage) -> CIImage? {
        let box = image.extent
        let upper = CGRect(x: box.minX, y: box.midY, width: box.width, height: box.height / 2)
        return CIImage(color: .white).cropped(to: upper).composited(over: image)
    }

    private static var red: CIImage { CIImage(color: .red).cropped(to: extent) }

    /// RGBA of texture row `row` (y = row), first column.
    private static func pixel(_ image: CIImage, row: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: 0, y: row, width: 1, height: 1),
                    format: .RGBA8, colorSpace: nil)
        return bytes
    }

    @Test("top-row-first frames are filtered upright and stored back the same way")
    func topRowFirst() {
        let output = FrameImageFilter.apply(Self.paintUpperHalf, to: Self.red, storedTopRowFirst: true)
        #expect(output.extent == Self.extent)
        #expect(Self.pixel(output, row: 1) == [255, 255, 255, 255])  // picture top = first rows
        #expect(Self.pixel(output, row: 6) == [255, 0, 0, 255])
    }

    @Test("bottom-row-first frames are already upright")
    func bottomRowFirst() {
        let output = FrameImageFilter.apply(Self.paintUpperHalf, to: Self.red, storedTopRowFirst: false)
        #expect(Self.pixel(output, row: 6) == [255, 255, 255, 255])  // picture top = last rows
        #expect(Self.pixel(output, row: 1) == [255, 0, 0, 255])
    }

    @Test("a blur leaves the edges opaque and the extent unchanged")
    func blurStaysOpaque() {
        let blur: ScreenImageFilter = { $0.applyingGaussianBlur(sigma: 3) }
        let output = FrameImageFilter.apply(blur, to: Self.red, storedTopRowFirst: true)
        #expect(output.extent == Self.extent)
        #expect(Self.pixel(output, row: 0)[3] == 255)
    }

    @Test("a filter that fails keeps the frame")
    func failedFilterKeepsFrame() {
        let output = FrameImageFilter.apply({ _ in nil }, to: Self.red, storedTopRowFirst: true)
        #expect(Self.pixel(output, row: 3) == [255, 0, 0, 255])
    }
}

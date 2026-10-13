//
//  LCDScreenComposerTests.swift
//  PVShadersTests
//

import CoreGraphics
import CoreImage
import Metal
import Testing
@testable import PVShaders

@Suite("LCDScreenComposer")
struct LCDScreenComposerTests {
    /// Source frame: two 16×12 screens stacked, the top one red and the bottom one blue,
    /// each with a green first row (y grows downwards, as in a texture).
    private static let screen = CGSize(width: 16, height: 12)
    private static let canvas = CGRect(x: 0, y: 0, width: 160, height: 260)

    private static func band(_ color: CIColor, _ rect: CGRect) -> CIImage {
        CIImage(color: color).cropped(to: rect)
    }

    private static var source: CIImage {
        let width = screen.width, height = screen.height
        let top = band(.green, CGRect(x: 0, y: 0, width: width, height: 1))
            .composited(over: band(.red, CGRect(x: 0, y: 0, width: width, height: height)))
        let bottom = band(.green, CGRect(x: 0, y: height, width: width, height: 1))
            .composited(over: band(.blue, CGRect(x: 0, y: height, width: width, height: height)))
        return top.composited(over: bottom)
    }

    private static func placement(_ index: Int, flipped: Bool = false, lcd: Bool = false) -> LCDScreenPlacement {
        LCDScreenPlacement(sourceRect: CGRect(x: 0, y: CGFloat(index) * screen.height,
                                              width: screen.width, height: screen.height),
                           sourceIsFlipped: flipped,
                           destinationRect: CGRect(x: 0, y: CGFloat(index) * 130, width: 160, height: 120),
                           nativeSize: screen,
                           appliesLCD: lcd)
    }

    /// RGBA of one output pixel at (x, y), y counted from the top row.
    private static func pixel(_ image: CIImage, _ col: Int, _ row: Int,
                              context: CIContext = CIContext(options: [.workingColorSpace: NSNull()])) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: col, y: row, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return bytes
    }

    @Test("each screen lands in its destination, upright, over black")
    func placesScreens() {
        let frame = LCDScreenComposer().compose(source: Self.source,
                                                 placements: [Self.placement(0), Self.placement(1)],
                                                 canvas: Self.canvas)
        #expect(frame.extent == Self.canvas)
        #expect(Self.pixel(frame, 80, 2)[1] > 200)       // top screen's first row (green)
        #expect(Self.pixel(frame, 80, 60)[0] > 200)      // top screen body (red)
        #expect(Self.pixel(frame, 80, 125) == [0, 0, 0, 255])  // gap between screens
        #expect(Self.pixel(frame, 80, 132)[1] > 200)     // bottom screen's first row
        #expect(Self.pixel(frame, 80, 200)[2] > 200)     // bottom screen body (blue)
    }

    @Test("a bottom-row-first region is turned upright")
    func flipsBottomUpSources() {
        // Stored bottom row first, the top screen's first row is the region's last row.
        let width = Self.screen.width, height = Self.screen.height
        let source = Self.band(.green, CGRect(x: 0, y: height - 1, width: width, height: 1))
            .composited(over: Self.band(.red, CGRect(x: 0, y: 0, width: width, height: height)))
        let frame = LCDScreenComposer().compose(source: source,
                                                 placements: [Self.placement(0, flipped: true)],
                                                 canvas: Self.canvas)
        #expect(Self.pixel(frame, 80, 2)[1] > 200)
        #expect(Self.pixel(frame, 80, 117)[0] > 200)
    }

    @Test("screen edges do not sample the neighbouring screen")
    func clampsEdges() {
        let frame = LCDScreenComposer().compose(source: Self.source, placements: [Self.placement(0)],
                                                 canvas: Self.canvas)
        let lastRow = Self.pixel(frame, 80, 119)
        #expect(lastRow[0] > 200 && lastRow[2] < 20)
    }

    @Test("without the LCD look colours pass through untouched")
    func plainScreensKeepColours() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let grey = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(origin: .zero, size: Self.screen))
        let frame = LCDScreenComposer().compose(source: grey, placements: [Self.placement(0)], canvas: Self.canvas)
        let value = Self.pixel(frame, 80, 60, context: LCDScreenComposer.makeContext(device: device))[0]
        #expect(abs(Int(value) - 128) <= 1)
    }

    @Test("the LCD look draws a grid on the emulated pixels")
    func drawsGrid() {
        let grey = CIImage(color: CIColor(red: 0.6, green: 0.6, blue: 0.6))
            .cropped(to: CGRect(origin: .zero, size: Self.screen))
        let frame = LCDScreenComposer().compose(source: grey, placements: [Self.placement(0, lcd: true)],
                                                 canvas: Self.canvas)
        // 10 output pixels per emulated pixel: a column inside a pixel against its gap.
        var bytes = [UInt8](repeating: 0, count: 160 * 4)
        CIContext().render(frame, toBitmap: &bytes, rowBytes: 160 * 4,
                           bounds: CGRect(x: 0, y: 55, width: 160, height: 1), format: .RGBA8, colorSpace: nil)
        let row = stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] }
        let darkest = row.min() ?? 0, brightest = row.max() ?? 0
        #expect(Int(brightest) - Int(darkest) > 30)
    }

    @Test("renders through Metal into a target texture")
    func rendersToTexture() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        func texture(_ width: Int, _ height: Int) throws -> MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width,
                                                                      height: height, mipmapped: false)
            descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            return try #require(device.makeTexture(descriptor: descriptor))
        }
        let width = Int(Self.screen.width), height = Int(Self.screen.height) * 2
        let source = try texture(width, height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let top = offset / 4 < width * height / 2
            pixels[offset] = top ? 0 : 255       // B
            pixels[offset + 2] = top ? 255 : 0   // R
            pixels[offset + 3] = 255
        }
        source.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels,
                       bytesPerRow: width * 4)
        let target = try texture(Int(Self.canvas.width), Int(Self.canvas.height))
        let commandBuffer = try #require(queue.makeCommandBuffer())
        let encoded = LCDScreenComposer().render(source: source, placements: [Self.placement(0), Self.placement(1)],
                                                 into: target, context: LCDScreenComposer.makeContext(device: device),
                                                 commandBuffer: commandBuffer)
        #expect(encoded)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        func read(_ col: Int, _ row: Int) -> [UInt8] {
            var bgra = [UInt8](repeating: 0, count: 4)
            target.getBytes(&bgra, bytesPerRow: 4, from: MTLRegionMake2D(col, row, 1, 1), mipmapLevel: 0)
            return bgra
        }
        #expect(read(80, 60)[2] > 200)    // top screen red, in the top destination
        #expect(read(80, 200)[0] > 200)   // bottom screen blue
        #expect(read(80, 125) == [0, 0, 0, 255])
    }
}

@Suite("LCDScreenFilter gap geometry")
struct LCDGapRectTests {
    @Test("one gap column per emulated column and one row per emulated row, inside the screen")
    func coversGrid() {
        let size = CGSize(width: 400, height: 240)
        let rects = LCDScreenFilter.gapRects(in: size, nativeSize: CGSize(width: 400, height: 240), scale: 3)
        #expect(rects.count == 640)
        let bounds = CGRect(origin: .zero, size: size)
        #expect(rects.allSatisfy { bounds.insetBy(dx: -0.001, dy: -0.001).contains($0) })
        #expect(abs(rects[0].width - 0.25) < 0.0001)
    }

    @Test("no grid when a pixel covers fewer than two device pixels")
    func skipsDenseGrids() {
        let rects = LCDScreenFilter.gapRects(in: CGSize(width: 300, height: 180),
                                             nativeSize: CGSize(width: 400, height: 240), scale: 2)
        #expect(rects.isEmpty)
    }

    @Test("a separate vertical pitch spaces the grid rows")
    func verticalPitch() throws {
        let grey = CIImage(color: CIColor(red: 0.6, green: 0.6, blue: 0.6))
            .cropped(to: CGRect(x: 0, y: 0, width: 32, height: 32))
        let filter = LCDScreenFilter()
        filter.inputImage = grey
        filter.inputPixelPitch = 8
        filter.inputPixelPitchY = 4
        filter.inputGhosting = 0
        filter.inputSaturation = 1
        filter.inputBrightness = 0
        filter.inputGridStrength = 0.5
        let output = try #require(filter.outputImage)
        var column = [UInt8](repeating: 0, count: 32 * 4)
        CIContext().render(output, toBitmap: &column, rowBytes: 4, bounds: CGRect(x: 2, y: 0, width: 1, height: 32),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let reds = stride(from: 0, to: column.count, by: 4).map { column[$0] }
        let brightest = try #require(reds.max())
        let gaps = reds.indices.filter { reds[$0] < brightest && ($0 == 0 || reds[$0 - 1] == brightest) }
        #expect(gaps.count == 32 / 4)
    }
}

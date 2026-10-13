//
//  ShaderPreviewSource.swift
//  PVShaders
//
//  The image a filter preview is rendered over: a built-in test pattern, a
//  procedurally drawn retro scene, or a frame captured from a running game.
//

import CoreGraphics
import Foundation
@preconcurrency import Metal

/// What a filter preview is drawn over.
///
/// The two procedural sources are generated with CoreGraphics (no bundled art)
/// and are fully deterministic, so a cache keyed on `cacheIdentity` stays valid
/// across launches.
public enum ShaderPreviewSource: Sendable {
    /// SMPTE-style colour bars, a grey ramp and fine line / checker areas that
    /// make scanline, mask and blur effects easy to judge.
    case testPattern
    /// A pixel-art scene at a console-like resolution.
    case sampleScene
    /// A captured game frame. `identity` must change whenever the frame does:
    /// it is part of the preview cache key.
    case frame(texture: MTLTexture, identity: Int)

    /// Pixel size of the `.testPattern` texture.
    public static let testPatternSize = CGSize(width: 320, height: 240)
    /// Pixel size of the `.sampleScene` texture.
    public static let sampleSceneSize = CGSize(width: 256, height: 224)

    /// Stable string identifying the source's pixels, for cache keys.
    public var cacheIdentity: String {
        switch self {
        case .testPattern: return "testPattern"
        case .sampleScene: return "sampleScene"
        case .frame(_, let identity): return "frame-\(identity)"
        }
    }

    /// `true` for game frames, which change every time and are not worth persisting.
    public var isGameFrame: Bool {
        if case .frame = self { return true }
        return false
    }

    /// The source as a texture on `device`. Procedural sources are built once per
    /// device and shared; a `.frame` returns its own texture unchanged.
    public func makeTexture(device: MTLDevice) throws -> MTLTexture {
        switch self {
        case .testPattern:
            return try ProceduralTextureCache.shared.texture(named: cacheIdentity, device: device) {
                ProceduralImages.testPattern()
            }
        case .sampleScene:
            return try ProceduralTextureCache.shared.texture(named: cacheIdentity, device: device) {
                ProceduralImages.sampleScene()
            }
        case .frame(let texture, _):
            return texture
        }
    }

    /// The picture's display aspect: 4:3 for both procedural sources (the scene's
    /// 256x224 pixels were not square on the consoles it imitates), the texture's
    /// own proportions for a game frame.
    func displayAspect(of texture: MTLTexture) -> CGSize {
        switch self {
        case .testPattern, .sampleScene:
            return Self.consoleDisplayAspect
        case .frame:
            return CGSize(width: texture.width, height: texture.height)
        }
    }

    private static let consoleDisplayAspect = CGSize(width: 4, height: 3)
}

// MARK: - Texture cache

/// Uploads each procedural image once per device.
private final class ProceduralTextureCache: @unchecked Sendable {
    static let shared = ProceduralTextureCache()

    private let lock = NSLock()
    private var textures: [String: MTLTexture] = [:]

    func texture(named name: String, device: MTLDevice, image: () -> CGImage) throws -> MTLTexture {
        let key = "\(device.registryID)-\(name)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = textures[key] { return cached }
        let texture = try Self.upload(image(), to: device)
        textures[key] = texture
        return texture
    }

    /// `.shared` storage: `replace(region:)` is illegal on `.private` textures, and
    /// the Simulator cannot blit-upload them reliably.
    private static func upload(_ image: CGImage, to device: MTLDevice) throws -> MTLTexture {
        let width = image.width
        let height = image.height
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width,
                                                                  height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw ShaderPreviewError.textureCreationFailed
        }
        let bytesPerRow = width * ProceduralImages.bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = ProceduralImages.makeContext(width: width, height: height, data: buffer.baseAddress,
                                                             bytesPerRow: bytesPerRow,
                                                             topLeftOrigin: false) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drewImage else { throw ShaderPreviewError.textureCreationFailed }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: pixels, bytesPerRow: bytesPerRow)
        return texture
    }
}

// MARK: - Procedural drawing

/// CoreGraphics drawing of the built-in sources. Everything is axis-aligned,
/// integer-positioned and unantialiased so pixels are exactly reproducible.
enum ProceduralImages {
    static let bytesPerPixel = 4

    /// A BGRA bitmap context. With `topLeftOrigin`, y grows downwards, which is how the
    /// drawing code below thinks; without it, drawing an image fills the buffer top row first.
    static func makeContext(width: Int, height: Int, data: UnsafeMutableRawPointer? = nil,
                            bytesPerRow: Int = 0, topLeftOrigin: Bool = true) -> CGContext? {
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo) else { return nil }
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        if topLeftOrigin {
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
        }
        return context
    }

    private struct RGB {
        let red: Int
        let green: Int
        let blue: Int

        init(_ red: Int, _ green: Int, _ blue: Int) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        static let black = RGB(0, 0, 0)
        static let white = RGB(255, 255, 255)
    }

    private static func fill(_ context: CGContext, _ color: RGB, _ x: Int, _ y: Int, _ width: Int, _ height: Int) {
        context.setFillColor(red: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255,
                             blue: CGFloat(color.blue) / 255, alpha: 1)
        context.fill(CGRect(x: x, y: y, width: width, height: height))
    }

    private static func image(width: Int, height: Int, draw: (CGContext) -> Void) -> CGImage {
        guard let context = makeContext(width: width, height: height) else {
            preconditionFailure("CoreGraphics could not allocate a \(width)x\(height) bitmap")
        }
        draw(context)
        guard let image = context.makeImage() else {
            preconditionFailure("CoreGraphics could not snapshot a \(width)x\(height) bitmap")
        }
        return image
    }

    // MARK: Test pattern

    private enum Bars {
        /// 75% white, yellow, cyan, green, magenta, red, blue.
        static let main: [RGB] = [
            RGB(191, 191, 191), RGB(191, 191, 0), RGB(0, 191, 191), RGB(0, 191, 0),
            RGB(191, 0, 191), RGB(191, 0, 0), RGB(0, 0, 191)
        ]
        /// The thin strip under the main bars: blue, black, magenta, black, cyan, black, grey.
        static let castellations: [RGB] = [
            RGB(0, 0, 191), .black, RGB(191, 0, 191), .black, RGB(0, 191, 191), .black, RGB(191, 191, 191)
        ]
        static let rampSteps = 16
        static let mainHeightFraction = 2.0 / 3.0
        static let castellationHeight = 20
        static let checkerCell = 4
    }

    /// Colour bars on top, then (left to right) a grey ramp over 1-pixel horizontal
    /// lines, 1-pixel vertical lines, and a 4-pixel checkerboard.
    static func testPattern() -> CGImage {
        let width = Int(ShaderPreviewSource.testPatternSize.width)
        let height = Int(ShaderPreviewSource.testPatternSize.height)
        return image(width: width, height: height) { context in
            let mainHeight = Int(Double(height) * Bars.mainHeightFraction)
            let barWidth = width / Bars.main.count
            for (index, color) in Bars.main.enumerated() {
                let x = index * barWidth
                let w = index == Bars.main.count - 1 ? width - x : barWidth
                fill(context, color, x, 0, w, mainHeight)
                fill(context, Bars.castellations[index], x, mainHeight, w, Bars.castellationHeight)
            }

            let lowerTop = mainHeight + Bars.castellationHeight
            let lowerHeight = height - lowerTop
            let halfWidth = width / 2
            let thirdWidth = (width - halfWidth) / 2
            let rampHeight = lowerHeight / 2

            // Left half: grey ramp, then alternating 1-pixel black / white rows.
            let stepWidth = halfWidth / Bars.rampSteps
            for step in 0 ..< Bars.rampSteps {
                let level = step * 255 / (Bars.rampSteps - 1)
                fill(context, RGB(level, level, level), step * stepWidth, lowerTop, stepWidth, rampHeight)
            }
            for row in 0 ..< lowerHeight - rampHeight {
                fill(context, row % 2 == 0 ? .white : .black, 0, lowerTop + rampHeight + row, halfWidth, 1)
            }

            // Right half: vertical 1-pixel lines, then a checkerboard.
            let linesLeft = halfWidth
            for column in 0 ..< thirdWidth {
                fill(context, column % 2 == 0 ? .white : .black, linesLeft + column, lowerTop, 1, lowerHeight)
            }
            let checkerLeft = linesLeft + thirdWidth
            let cell = Bars.checkerCell
            for row in 0 ..< (lowerHeight + cell - 1) / cell {
                for column in 0 ..< (width - checkerLeft + cell - 1) / cell where (row + column) % 2 == 0 {
                    fill(context, .white, checkerLeft + column * cell, lowerTop + row * cell, cell, cell)
                }
            }
        }
    }

    // MARK: Sample scene

    private enum Scene {
        static let skyTop = RGB(24, 96, 200)
        static let skyBottom = RGB(152, 216, 248)
        static let skyBandHeight = 8
        static let cloud = RGB(248, 248, 248)
        static let cloudShade = RGB(200, 224, 248)
        static let farHill = RGB(40, 152, 96)
        static let nearHill = RGB(24, 112, 56)
        static let grass = RGB(88, 200, 48)
        static let dirt = RGB(176, 96, 40)
        static let dirtLight = RGB(232, 144, 72)
        static let dirtDark = RGB(96, 48, 16)
        static let hudText = RGB(248, 248, 248)
        static let hudShadow = RGB(0, 0, 0)

        static let brick = 16
        static let groundRows = 2
        static let grassHeight = 4
        static let hudMargin = 8
        static let glyphScale = 2
        static let glyphWidth = 3
        static let glyphHeight = 5
        static let glyphAdvance = 4
        static let farHillPeriod = 96
        static let farHillBase = 56
        static let nearHillPeriod = 64
        static let nearHillBase = 28
        static let spriteScale = 2
        static let spriteBrickX = 6

        /// 3x5 digit glyphs, one bit per cell, row-major from the top-left.
        static let digits: [[UInt8]] = [
            [7, 5, 5, 5, 7], [2, 6, 2, 2, 7], [7, 1, 7, 4, 7], [7, 1, 7, 1, 7], [5, 5, 7, 1, 1],
            [7, 4, 7, 1, 7], [7, 4, 7, 5, 7], [7, 1, 1, 1, 1], [7, 5, 7, 5, 7], [7, 5, 7, 1, 7]
        ]

        /// 12x16 sprite, `.` transparent, `k` outline, `r` cap, `s` skin, `b` overalls.
        static let sprite: [String] = [
            "...kkkkk....",
            "..krrrrrkk..",
            ".krrrrrrrrk.",
            ".kkkssskskk.",
            "kssksssskss.",
            "kssksssskssk",
            "kkssssskkkk.",
            "..kssssssk..",
            "..kkbbkbbk..",
            ".kbbbbkbbbk.",
            "kbbbbbkbbbbk",
            "kssbbbbbbssk",
            "kss.bbbb.ssk",
            "..kbbbbbbk..",
            ".kkkk..kkkk.",
            "kkkkk..kkkkk"
        ]
        static let spritePalette: [Character: RGB] = [
            "k": RGB(16, 16, 16), "r": RGB(216, 40, 0), "s": RGB(252, 188, 140),
            "b": RGB(0, 88, 216)
        ]
    }

    /// Sky gradient, clouds, two hill layers, a brick ground row, a small sprite
    /// and a score line, all at 256x224.
    static func sampleScene() -> CGImage {
        let width = Int(ShaderPreviewSource.sampleSceneSize.width)
        let height = Int(ShaderPreviewSource.sampleSceneSize.height)
        return image(width: width, height: height) { context in
            let groundTop = height - Scene.groundRows * Scene.brick
            drawSky(context, width: width, height: groundTop)
            drawClouds(context)
            drawHills(context, width: width, groundTop: groundTop)
            drawGround(context, width: width, top: groundTop)
            drawSprite(context, groundTop: groundTop)
            drawHUD(context, width: width)
        }
    }

    private static func lerp(_ from: RGB, _ to: RGB, _ amount: Double) -> RGB {
        func mix(_ a: Int, _ b: Int) -> Int { a + Int((Double(b - a) * amount).rounded()) }
        return RGB(mix(from.red, to.red), mix(from.green, to.green), mix(from.blue, to.blue))
    }

    private static func drawSky(_ context: CGContext, width: Int, height: Int) {
        let bands = (height + Scene.skyBandHeight - 1) / Scene.skyBandHeight
        for band in 0 ..< bands {
            let color = lerp(Scene.skyTop, Scene.skyBottom, Double(band) / Double(max(bands - 1, 1)))
            fill(context, color, 0, band * Scene.skyBandHeight, width, Scene.skyBandHeight)
        }
    }

    private static func drawClouds(_ context: CGContext) {
        for (x, y) in [(28, 36), (150, 22), (212, 60)] {
            fill(context, Scene.cloudShade, x, y + 8, 40, 8)
            fill(context, Scene.cloud, x + 4, y + 4, 32, 8)
            fill(context, Scene.cloud, x + 12, y, 16, 8)
        }
    }

    /// Triangle-wave height, so hills are plain integer maths and identical everywhere.
    private static func hillHeight(at x: Int, period: Int, base: Int) -> Int {
        let phase = x % period
        let rise = phase < period / 2 ? phase : period - phase
        return base + rise / 2
    }

    private static func drawHills(_ context: CGContext, width: Int, groundTop: Int) {
        for (color, period, base) in [(Scene.farHill, Scene.farHillPeriod, Scene.farHillBase),
                                      (Scene.nearHill, Scene.nearHillPeriod, Scene.nearHillBase)] {
            for x in 0 ..< width {
                let height = hillHeight(at: x + base, period: period, base: base)
                fill(context, color, x, groundTop - height, 1, height)
            }
        }
    }

    private static func drawGround(_ context: CGContext, width: Int, top: Int) {
        let brick = Scene.brick
        for row in 0 ..< Scene.groundRows {
            for column in 0 ..< (width + brick - 1) / brick {
                let x = column * brick
                let y = top + row * brick
                fill(context, Scene.dirt, x, y, brick, brick)
                fill(context, Scene.dirtLight, x, y, brick, 1)
                fill(context, Scene.dirtLight, x, y, 1, brick)
                fill(context, Scene.dirtDark, x, y + brick - 1, brick, 1)
                fill(context, Scene.dirtDark, x + brick - 1, y, 1, brick)
            }
        }
        fill(context, Scene.grass, 0, top, width, Scene.grassHeight)
    }

    private static func drawSprite(_ context: CGContext, groundTop: Int) {
        let scale = Scene.spriteScale
        let originX = Scene.spriteBrickX * Scene.brick
        let originY = groundTop - Scene.sprite.count * scale
        for (row, line) in Scene.sprite.enumerated() {
            for (column, character) in line.enumerated() {
                guard let color = Scene.spritePalette[character] else { continue }
                fill(context, color, originX + column * scale, originY + row * scale, scale, scale)
            }
        }
    }

    private static func drawHUD(_ context: CGContext, width: Int) {
        func draw(_ text: [Int], atX x: Int, y: Int) {
            for (index, digit) in text.enumerated() {
                for (row, bits) in Scene.digits[digit].enumerated() {
                    for column in 0 ..< Scene.glyphWidth where bits & (1 << (Scene.glyphWidth - 1 - column)) != 0 {
                        let cellX = x + (index * Scene.glyphAdvance + column) * Scene.glyphScale
                        let cellY = y + row * Scene.glyphScale
                        fill(context, Scene.hudShadow, cellX + 1, cellY + 1, Scene.glyphScale, Scene.glyphScale)
                        fill(context, Scene.hudText, cellX, cellY, Scene.glyphScale, Scene.glyphScale)
                    }
                }
            }
        }
        let textWidth = { (count: Int) in count * Scene.glyphAdvance * Scene.glyphScale }
        let score = [0, 0, 1, 2, 3, 0]
        let lives = [0, 3]
        draw(score, atX: Scene.hudMargin, y: Scene.hudMargin)
        draw(lives, atX: width - Scene.hudMargin - textWidth(lives.count), y: Scene.hudMargin)
    }
}

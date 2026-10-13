//
//  ShaderPreviewTests.swift
//  PVShadersTests
//
//  Preview sources, the offscreen renderer (on the host GPU) and the cache's
//  scheduling rules (with a stub renderer).
//

import CoreGraphics
import Foundation
import ImageIO
import Metal
import PVSettings
import Testing
@testable import PVShaders

// MARK: - Helpers

/// RGBA bytes of `image`, row by row from the top.
private func rgbaBytes(of image: CGImage) -> [UInt8] {
    let bytesPerRow = image.width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    #expect(drawn)
    return bytes
}

private func pixel(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> [UInt8] {
    let offset = (y * width + x) * 4
    return Array(bytes[offset ..< offset + 3])
}

private func distinctColours(in bytes: [UInt8]) -> Int {
    var seen = Set<[UInt8]>()
    for offset in stride(from: 0, to: bytes.count, by: 4) {
        seen.insert(Array(bytes[offset ..< offset + 3]))
    }
    return seen.count
}

private func textureBytes(_ texture: MTLTexture) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
    texture.getBytes(&bytes, bytesPerRow: texture.width * 4,
                     from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
    return bytes
}

private func nativeEntry(_ option: MetalFilterSelectionOption) throws -> ShaderCatalogEntry {
    try #require(ShaderCatalog(libraryURL: nil).entry(for: .native(option)))
}

private func fixtureEntry(_ name: String) throws -> ShaderCatalogEntry {
    let directory = FilterChainTests.fixture(name)
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("shader.json")))
    let declared = ((manifest as? [String: Any])?["parameters"] as? [[String: Any]]) ?? []
    let parameters = declared.compactMap { item -> ShaderParameterDescriptor? in
        guard let name = item["name"] as? String,
              let initial = (item["initial"] as? NSNumber)?.floatValue,
              let minimum = (item["minimum"] as? NSNumber)?.floatValue,
              let maximum = (item["maximum"] as? NSNumber)?.floatValue else { return nil }
        return ShaderParameterDescriptor(name: name, label: name, initial: initial, minimum: minimum,
                                         maximum: maximum, step: 0)
    }
    return ShaderCatalogEntry(id: .slang("test/\(name)"), name: name, category: "test", passes: 1,
                              historyFrames: 0, usesFeedback: false, lutCount: 0, parameters: parameters,
                              directory: directory)
}

/// `swift build` copies the native `.metal` sources without compiling them; only Xcode produces the
/// `default.metallib` the native filters load.
private let nativeShadersAvailable: Bool = {
    guard let device = MTLCreateSystemDefaultDevice() else { return false }
    return (try? device.makeDefaultLibrary(bundle: MetalShaderManager.shared.shaderBundle)) != nil
}()

private let defaultValue: @Sendable (ShaderParameterDescriptor) -> Float = { $0.initial }

// MARK: - Sources

@Suite("ShaderPreviewSource")
struct ShaderPreviewSourceTests {
    @Test("the test pattern and sample scene have their declared size and more than one colour")
    func proceduralTextures() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        for (source, size) in [(ShaderPreviewSource.testPattern, ShaderPreviewSource.testPatternSize),
                               (ShaderPreviewSource.sampleScene, ShaderPreviewSource.sampleSceneSize)] {
            let texture = try source.makeTexture(device: device)
            #expect(texture.width == Int(size.width))
            #expect(texture.height == Int(size.height))
            #expect(distinctColours(in: textureBytes(texture)) > 8)
        }
    }

    @Test("procedural textures are cached per device and deterministic")
    func proceduralTexturesAreStable() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let first = try ShaderPreviewSource.testPattern.makeTexture(device: device)
        let second = try ShaderPreviewSource.testPattern.makeTexture(device: device)
        #expect(first === second)
        let scene = textureBytes(try ShaderPreviewSource.sampleScene.makeTexture(device: device))
        let again = ProceduralImages.sampleScene()
        let identical = scene == rgbaToBGRA(rgbaBytes(of: again))
        #expect(identical)
    }

    @Test("the test pattern puts colour bars on top and fine detail below")
    func testPatternLayout() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let texture = try ShaderPreviewSource.testPattern.makeTexture(device: device)
        let bytes = textureBytes(texture)
        let width = texture.width
        // BGRA: first bar is 75% grey, second is yellow (blue channel 0).
        #expect(Array(bytes[(10 * width + 10) * 4 ..< (10 * width + 10) * 4 + 3]) == [191, 191, 191])
        let yellow = (10 * width + width / 7 + 10) * 4
        #expect(Array(bytes[yellow ..< yellow + 3]) == [0, 191, 191])
        // The 1-pixel row pattern near the bottom-left alternates between rows.
        let rowA = (texture.height - 1) * width * 4
        let rowB = (texture.height - 2) * width * 4
        #expect(bytes[rowA] != bytes[rowB])
    }

    @Test("cache identities are stable and distinguish frames")
    func cacheIdentity() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let texture = try ShaderPreviewSource.testPattern.makeTexture(device: device)
        #expect(ShaderPreviewSource.testPattern.cacheIdentity == "testPattern")
        #expect(ShaderPreviewSource.sampleScene.cacheIdentity == "sampleScene")
        #expect(ShaderPreviewSource.frame(texture: texture, identity: 1).cacheIdentity
            != ShaderPreviewSource.frame(texture: texture, identity: 2).cacheIdentity)
        #expect(ShaderPreviewSource.frame(texture: texture, identity: 1).isGameFrame)
        #expect(!ShaderPreviewSource.testPattern.isGameFrame)
    }

    private func rgbaToBGRA(_ rgba: [UInt8]) -> [UInt8] {
        var out = rgba
        for offset in stride(from: 0, to: out.count, by: 4) {
            out.swapAt(offset, offset + 2)
        }
        return out
    }
}

// MARK: - Renderer

@Suite("ShaderPreviewRenderer")
struct ShaderPreviewRendererTests {
    private let size = CGSize(width: 480, height: 360)

    private func makeRenderer() throws -> ShaderPreviewRenderer {
        try ShaderPreviewRenderer(device: try #require(MTLCreateSystemDefaultDevice()))
    }

    @Test("a single-pass passthrough preset reproduces the source, upright")
    func passthroughIsUpright() async throws {
        let renderer = try makeRenderer()
        let image = try await renderer.render(entry: fixtureEntry("nearest"), source: .testPattern,
                                              size: ShaderPreviewSource.testPatternSize, parameterValue: defaultValue)
        #expect(image.width == 320)
        #expect(image.height == 240)
        let bytes = rgbaBytes(of: image)
        // Top-left bar is 75% grey; the bottom rows hold the fine line pattern, not bars.
        #expect(pixel(bytes, width: 320, x: 10, y: 10) == [191, 191, 191])
        #expect(pixel(bytes, width: 320, x: 10, y: 100) == [191, 191, 191])
        #expect(pixel(bytes, width: 320, x: 10 + 320 / 7, y: 10) == [191, 191, 0])
    }

    @Test("the source keeps its aspect and the rest is black")
    func letterboxes() async throws {
        let renderer = try makeRenderer()
        let image = try await renderer.render(entry: fixtureEntry("nearest"), source: .testPattern,
                                              size: CGSize(width: 400, height: 400), parameterValue: defaultValue)
        let bytes = rgbaBytes(of: image)
        // 4:3 in a square: 300 rows of picture centred, 50 black rows above and below.
        #expect(pixel(bytes, width: 400, x: 200, y: 10) == [0, 0, 0])
        #expect(pixel(bytes, width: 400, x: 200, y: 390) == [0, 0, 0])
        #expect(pixel(bytes, width: 400, x: 20, y: 80) == [191, 191, 191])
    }

    @Test("native VHS and LCD previews differ from an unfiltered render",
          .enabled(if: nativeShadersAvailable, "needs the compiled default.metallib, which only Xcode builds produce"),
          arguments: [MetalFilterSelectionOption.vhs.rawValue, MetalFilterSelectionOption.lcd.rawValue])
    func nativeFiltersChangeTheImage(optionName: String) async throws {
        let option = try #require(MetalFilterSelectionOption(rawValue: optionName))
        let renderer = try makeRenderer()
        let plain = try await renderer.render(entry: fixtureEntry("nearest"), source: .testPattern, size: size,
                                              parameterValue: defaultValue)
        let filtered = try await renderer.render(entry: nativeEntry(option), source: .testPattern, size: size,
                                                 parameterValue: defaultValue)
        #expect(filtered.width == 480)
        #expect(filtered.height == 360)
        let filteredBytes = rgbaBytes(of: filtered)
        #expect(distinctColours(in: filteredBytes) > 8)
        let differs = filteredBytes != rgbaBytes(of: plain)
        #expect(differs)
    }

    @Test("a multi-pass slang preset renders and differs from passthrough")
    func slangPresetRenders() async throws {
        let renderer = try makeRenderer()
        let plain = try await renderer.render(entry: fixtureEntry("nearest"), source: .sampleScene, size: size,
                                              parameterValue: defaultValue)
        let crt = try fixtureEntry("crt-geom-mini")
        let filtered = try await renderer.render(entry: crt, source: .sampleScene, size: size,
                                                 parameterValue: defaultValue)
        #expect(filtered.width == 480)
        #expect(distinctColours(in: rgbaBytes(of: filtered)) > 8)
        let differsFromPassthrough = rgbaBytes(of: filtered) != rgbaBytes(of: plain)
        #expect(differsFromPassthrough)

        // The chain is reused; changing a parameter changes the picture.
        let parameter = try #require(crt.editableParameters.first { $0.maximum > $0.minimum })
        let altered = try await renderer.render(entry: crt, source: .sampleScene, size: size) { candidate in
            candidate.name == parameter.name ? parameter.maximum : candidate.initial
        }
        let baseline = try await renderer.render(entry: crt, source: .sampleScene, size: size,
                                                 parameterValue: defaultValue)
        let reusedChainIsStable = rgbaBytes(of: baseline) == rgbaBytes(of: filtered)
        #expect(reusedChainIsStable)
        if parameter.maximum != parameter.initial {
            let parameterChangesPicture = rgbaBytes(of: altered) != rgbaBytes(of: baseline)
            #expect(parameterChangesPicture)
        }
    }

    @Test("a captured game frame is previewed at its own aspect")
    func gameFrame() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let frame = try ShaderPreviewSource.sampleScene.makeTexture(device: device)
        let renderer = try ShaderPreviewRenderer(device: device)
        let image = try await renderer.render(entry: fixtureEntry("nearest"),
                                              source: .frame(texture: frame, identity: 7),
                                              size: CGSize(width: 256, height: 256), parameterValue: defaultValue)
        let bytes = rgbaBytes(of: image)
        // 256x224 in a square: 16 black rows above and below.
        #expect(pixel(bytes, width: 256, x: 128, y: 4) == [0, 0, 0])
        #expect(pixel(bytes, width: 256, x: 128, y: 128) != [0, 0, 0])
    }

    @Test("invalid sizes and library-less presets are rejected")
    func rejectsBadInput() async throws {
        let renderer = try makeRenderer()
        await #expect(throws: ShaderPreviewError.invalidSize) {
            _ = try await renderer.render(entry: nativeEntry(.vhs), source: .testPattern, size: .zero,
                                          parameterValue: defaultValue)
        }
        let orphan = ShaderCatalogEntry(id: .slang("missing"), name: "missing", category: "test", passes: 1,
                                        historyFrames: 0, usesFeedback: false, lutCount: 0, parameters: [],
                                        directory: nil)
        await #expect(throws: ShaderPreviewError.unsupportedFilter) {
            _ = try await renderer.render(entry: orphan, source: .testPattern, size: CGSize(width: 64, height: 48),
                                          parameterValue: defaultValue)
        }
    }
}

// MARK: - Cache

/// Counts calls to a stub render function and how many run at once.
private actor RenderProbe {
    private(set) var calls = 0
    private(set) var active = 0
    private(set) var maxActive = 0
    private(set) var finished = 0
    private(set) var rendered: [String] = []

    func begin(_ name: String) {
        calls += 1
        active += 1
        maxActive = max(maxActive, active)
        rendered.append(name)
    }

    func end() {
        active -= 1
        finished += 1
    }
}

private func stubImage(width: Int = 4, height: Int = 4, grey: UInt8 = 128) throws -> CGImage {
    let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(red: CGFloat(grey) / 255, green: 0.25, blue: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return try #require(context.makeImage())
}

private func stubEntry(_ name: String = "a") -> ShaderCatalogEntry {
    ShaderCatalogEntry(id: .slang("test/\(name)"), name: name, category: "test", passes: 1, historyFrames: 0,
                       usesFeedback: false, lutCount: 0,
                       parameters: [ShaderParameterDescriptor(name: "p", label: "p", initial: 0.5, minimum: 0,
                                                              maximum: 1, step: 0)],
                       directory: nil)
}

private func makeCache(probe: RenderProbe,
                       delay: Duration = .zero,
                       diskDirectory: URL? = nil,
                       memoryLimit: Int = ShaderPreviewCache.defaultMemoryLimit,
                       maxConcurrentRenders: Int = ShaderPreviewCache.defaultMaxConcurrentRenders,
                       timeout: Duration = ShaderPreviewCache.defaultTimeout) -> ShaderPreviewCache {
    ShaderPreviewCache(diskDirectory: diskDirectory, memoryLimit: memoryLimit,
                       maxConcurrentRenders: maxConcurrentRenders, timeout: timeout) { entry, _, size, _ in
        await probe.begin(entry.name)
        defer { Task { await probe.end() } }
        if delay > .zero { try await Task.sleep(for: delay) }
        return try stubImage(width: Int(size.width), height: Int(size.height))
    }
}

private let thumbnail = CGSize(width: 8, height: 6)

@Suite("ShaderPreviewCache")
struct ShaderPreviewCacheTests {
    @Test("concurrent identical requests share one render")
    func dedupesConcurrentRequests() async throws {
        let probe = RenderProbe()
        let cache = makeCache(probe: probe, delay: .milliseconds(100))
        let entry = stubEntry()
        let images = await withTaskGroup(of: CGImage?.self) { group in
            for _ in 0 ..< 5 {
                group.addTask { await cache.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue) }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        #expect(images.count == 5)
        #expect(images.allSatisfy { $0?.width == 8 })
        #expect(await probe.calls == 1)

        // And the result is cached afterwards.
        _ = await cache.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        #expect(await probe.calls == 1)
    }

    @Test("different sizes, sources and parameter values are different previews")
    func keysDistinguishInputs() async throws {
        let entry = stubEntry()
        let base = ShaderPreviewKey(entry: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        #expect(base == ShaderPreviewKey(entry: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue))
        #expect(base != ShaderPreviewKey(entry: entry, source: .sampleScene, size: thumbnail, parameterValue: defaultValue))
        #expect(base != ShaderPreviewKey(entry: entry, source: .testPattern, size: CGSize(width: 9, height: 6),
                                         parameterValue: defaultValue))
        #expect(base != ShaderPreviewKey(entry: entry, source: .testPattern, size: thumbnail) { _ in 0.9 })
        #expect(base.fileStem(version: "1") != base.fileStem(version: "2"))
    }

    @Test("a native filter's key follows its Defaults values, not the closure")
    func nativeKeysFollowDefaults() throws {
        let entry = try nativeEntry(.lcd)
        let parameter = try #require(entry.editableParameters.first { !$0.isToggle })
        let original = NativeShaderParameters.value(of: parameter)
        defer { NativeShaderParameters.set(original, for: parameter) }
        let before = ShaderPreviewKey(entry: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        let changed = parameter.clamp(original == parameter.maximum ? parameter.minimum : parameter.maximum)
        NativeShaderParameters.set(changed, for: parameter)
        let after = ShaderPreviewKey(entry: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        #expect(before != after)
    }

    @Test("at most two renders run at once")
    func capsConcurrency() async throws {
        let probe = RenderProbe()
        let cache = makeCache(probe: probe, delay: .milliseconds(60))
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 6 {
                group.addTask {
                    let size = CGSize(width: 8 + index, height: 6)
                    _ = await cache.preview(for: stubEntry("\(index)"), source: .testPattern, size: size,
                                            parameterValue: defaultValue)
                }
            }
        }
        #expect(await probe.calls == 6)
        #expect(await probe.maxActive == 2)
    }

    @Test("the least recently used image is evicted first")
    func evictsLeastRecentlyUsed() async throws {
        let probe = RenderProbe()
        let cache = makeCache(probe: probe, memoryLimit: 2)
        func request(_ name: String) async {
            _ = await cache.preview(for: stubEntry(name), source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        }
        await request("a")
        await request("b")
        await request("c") // evicts a
        #expect(await probe.calls == 3)
        await request("b") // hit, now b is newest
        #expect(await probe.calls == 3)
        await request("a") // miss, evicts c
        #expect(await probe.calls == 4)
        await request("b") // still cached
        #expect(await probe.calls == 4)
        await request("c") // gone
        #expect(await probe.calls == 5)
    }

    @Test("a slow render returns nil at the timeout but still fills the cache")
    func timeoutReturnsNilThenCaches() async throws {
        let probe = RenderProbe()
        let cache = makeCache(probe: probe, delay: .milliseconds(300), timeout: .milliseconds(50))
        let entry = stubEntry()
        let started = ContinuousClock.now
        let first = await cache.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        #expect(first == nil)
        #expect(ContinuousClock.now - started < .milliseconds(250))

        for _ in 0 ..< 100 where await probe.finished == 0 {
            try await Task.sleep(for: .milliseconds(20))
        }
        let second = await cache.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        #expect(second != nil)
        #expect(await probe.calls == 1)
    }

    @Test("a failed render returns nil and is not cached")
    func failuresAreNotCached() async throws {
        struct Boom: Error {}
        let probe = RenderProbe()
        let cache = ShaderPreviewCache { entry, _, _, _ in
            await probe.begin(entry.name)
            await probe.end()
            throw Boom()
        }
        let entry = stubEntry()
        #expect(await cache.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue) == nil)
        #expect(await cache.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue) == nil)
        #expect(await probe.calls == 2)
    }

    @Test("a request abandoned while queued never renders")
    func cancelledRequestsAreSkipped() async throws {
        let probe = RenderProbe()
        let cache = makeCache(probe: probe, delay: .milliseconds(200), maxConcurrentRenders: 1)
        let blocker = Task {
            await cache.preview(for: stubEntry("blocker"), source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        }
        try await Task.sleep(for: .milliseconds(50))
        let queued = Task {
            await cache.preview(for: stubEntry("queued"), source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        }
        try await Task.sleep(for: .milliseconds(50))
        queued.cancel()
        #expect(await queued.value == nil)
        #expect(await blocker.value != nil)
        #expect(await probe.rendered == ["blocker"])
    }

    @Test("previews persist on disk across caches, except game frames")
    func diskTier() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShaderPreviewTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = stubEntry()

        let writer = makeCache(probe: RenderProbe(), diskDirectory: directory)
        _ = await writer.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.count == 1)
        #expect(files.first?.hasSuffix(".png") == true)

        let probe = RenderProbe()
        let reader = makeCache(probe: probe, diskDirectory: directory)
        let loaded = await reader.preview(for: entry, source: .testPattern, size: thumbnail, parameterValue: defaultValue)
        #expect(loaded?.width == 8)
        #expect(loaded?.height == 6)
        #expect(await probe.calls == 0)

        let device = try #require(MTLCreateSystemDefaultDevice())
        let frame = ShaderPreviewSource.frame(texture: try ShaderPreviewSource.testPattern.makeTexture(device: device),
                                              identity: 1)
        _ = await writer.preview(for: entry, source: frame, size: thumbnail, parameterValue: defaultValue)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)

        await writer.removeAll()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("the renderer-backed cache renders a real preview")
    func rendererBackedCache() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let cache = ShaderPreviewCache(renderer: try ShaderPreviewRenderer(device: device), timeout: .seconds(10))
        let entry = try fixtureEntry("nearest")
        let image = await cache.preview(for: entry, source: .testPattern, size: CGSize(width: 160, height: 120),
                                        parameterValue: defaultValue)
        #expect(image?.width == 160)
        #expect(image?.height == 120)
    }
}

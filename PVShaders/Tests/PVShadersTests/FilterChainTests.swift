//
//  FilterChainTests.swift
//  PVShadersTests
//
//  Renders real compiled presets through the slang runtime on the host GPU.
//

import Foundation
import Metal
import Testing
@testable import PVSlangRuntime

@Suite("FilterChain")
struct FilterChainTests {
    static let device = MTLCreateSystemDefaultDevice()

    static func fixture(_ name: String) -> URL {
        Bundle.module.bundleURL.appendingPathComponent("Fixtures").appendingPathComponent(name)
    }

    @Test("the runtime metallib loads from the package bundle")
    func runtimeLibraryLoads() throws {
        let device = try #require(Self.device)
        let library = try RuntimeLibrary.library(for: device, source: .shaders)
        #expect(library.functionNames.contains("basic_vertex_proj_tex"))
        _ = try FilterChain(device: device)
    }

    @Test("a single-pass preset passes a flat colour through unchanged")
    func singlePassPassthrough() throws {
        let device = try #require(Self.device)
        let pixel = try renderFlatColour(device: device, preset: "nearest", bgra: [40, 120, 200, 255])
        #expect(pixel == [40, 120, 200, 255])
    }

    @Test("a two-pass preset renders through its intermediate target")
    func twoPassRenders() throws {
        let device = try #require(Self.device)
        let container = try DirectoryCompiledShaderContainer(directory: Self.fixture("linear-gamma-correct"))
        #expect(container.shader.passes.count == 2)
        let pixel = try renderFlatColour(device: device, preset: "linear-gamma-correct", bgra: [40, 120, 200, 255])
        // Gamma round trip: allow small rounding differences.
        for (got, want) in zip(pixel, [40, 120, 200, 255] as [UInt8]) {
            #expect(abs(Int(got) - Int(want)) <= 3)
        }
    }

    @Test("a hand-written preset with a vertex_main entry point loads")
    func nativeMetalEntryPoint() throws {
        let device = try #require(Self.device)
        let chain = try FilterChain(device: device)
        try chain.setCompiledShader(DirectoryCompiledShaderContainer(directory: Self.fixture("hologram")))
        #expect(chain.hasShader)
    }

    @Test("parameters decode with their ranges")
    func parametersDecode() throws {
        let container = try DirectoryCompiledShaderContainer(directory: Self.fixture("crt-geom-mini"))
        let parameters = container.shader.parameters
        #expect(!parameters.isEmpty)
        for parameter in parameters {
            #expect(parameter.minimum <= parameter.initial)
            #expect(parameter.initial <= parameter.maximum)
        }
    }

    @Test("a malformed preset throws instead of trapping")
    func malformedThrows() {
        #expect(throws: (any Error).self) {
            _ = try DirectoryCompiledShaderContainer(directory: Self.fixture("malformed"))
        }
        #expect(throws: DirectoryCompiledShaderContainer.Error.missingCompiledShader) {
            _ = try DirectoryCompiledShaderContainer(directory: Self.fixture("does-not-exist"))
        }
    }

    // MARK: - Helpers

    /// Fills a 32x32 source with one colour, renders `preset` into a 64x64
    /// target and returns the centre pixel as BGRA bytes.
    private func renderFlatColour(device: MTLDevice, preset: String, bgra: [UInt8]) throws -> [UInt8] {
        let sourceSize = 32
        let targetSize = 64
        let chain = try FilterChain(device: device)
        try chain.setCompiledShader(DirectoryCompiledShaderContainer(directory: Self.fixture(preset)))

        let sourceDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: sourceSize, height: sourceSize, mipmapped: false)
        sourceDescriptor.usage = [.shaderRead]
        sourceDescriptor.storageMode = .shared
        let source = try #require(device.makeTexture(descriptor: sourceDescriptor))
        let bytes = (0 ..< sourceSize * sourceSize * 4).map { bgra[$0 % 4] }
        source.replace(region: MTLRegionMake2D(0, 0, sourceSize, sourceSize),
                       mipmapLevel: 0, withBytes: bytes, bytesPerRow: sourceSize * 4)

        let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: targetSize, height: targetSize, mipmapped: false)
        targetDescriptor.usage = [.renderTarget, .shaderRead]
        targetDescriptor.storageMode = .shared
        let target = try #require(device.makeTexture(descriptor: targetDescriptor))

        chain.drawableSize = CGSize(width: targetSize, height: targetSize)
        chain.setSourceRect(CGRect(x: 0, y: 0, width: sourceSize, height: sourceSize),
                            aspect: CGSize(width: targetSize, height: targetSize))

        let queue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(queue.makeCommandBuffer())
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        chain.render(sourceTexture: source, commandBuffer: commandBuffer, renderPassDescriptor: pass)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        #expect(commandBuffer.error == nil)

        var out = [UInt8](repeating: 0, count: 4)
        target.getBytes(&out, bytesPerRow: targetSize * 4,
                        from: MTLRegionMake2D(targetSize / 2, targetSize / 2, 1, 1), mipmapLevel: 0)
        return out
    }
}

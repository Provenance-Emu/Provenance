//
//  ShaderPostProcessorTests.swift
//  PVShadersTests
//

import Foundation
import Metal
import Testing
@testable import PVShaders

@Suite("ShaderPostProcessor")
struct ShaderPostProcessorTests {
    @Test("draws nothing without a filter, then a library preset once it has compiled")
    func drawsLibraryPresetWhenReady() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let processor = ShaderPostProcessor(device: device)
        let size = 32
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: size,
                                                                  height: size, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let source = try #require(device.makeTexture(descriptor: descriptor))
        let target = try #require(device.makeTexture(descriptor: descriptor))
        let queue = try #require(device.makeCommandQueue())

        func drawOnce() throws -> Bool {
            let commandBuffer = try #require(queue.makeCommandBuffer())
            let drew = processor.render(source: source, target: target, commandBuffer: commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return drew
        }

        #expect(!processor.hasFilter)
        #expect(try !drawOnce())

        let entry = ShaderCatalogEntry(id: .slang("test/nearest"), name: "nearest", category: "test", passes: 1,
                                       historyFrames: 0, usesFeedback: false, lutCount: 0, parameters: [],
                                       directory: Bundle.module.bundleURL.appendingPathComponent("Fixtures/nearest"))
        processor.update(ResolvedShader(entry: entry, values: [:], revision: 1), smoothing: false)
        #expect(processor.hasFilter)
        var drew = false
        for _ in 0 ..< 100 where !drew {
            drew = try drawOnce()
            if !drew { try await Task.sleep(nanoseconds: 50_000_000) }
        }
        #expect(drew)

        processor.update(nil, smoothing: false)
        #expect(try !drawOnce())
    }
}

//
//  SlangFilterRendererTests.swift
//  PVShadersTests
//

import Foundation
import Metal
import Testing
@testable import PVShaders

@Suite("SlangFilterRenderer")
@MainActor
struct SlangFilterRendererTests {
    @Test("loads in the background, then draws only inside the content rect")
    func drawsInsideContentRect() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let fixture = Bundle.module.bundleURL.appendingPathComponent("Fixtures/nearest")
        let entry = ShaderCatalogEntry(id: .slang("test/nearest"), name: "nearest", category: "test", passes: 1,
                                       historyFrames: 0, usesFeedback: false, lutCount: 0, parameters: [],
                                       directory: fixture)
        let renderer = SlangFilterRenderer(device: device)
        #expect(!renderer.prepare(entry))
        for _ in 0 ..< 100 where !renderer.prepare(entry) {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(renderer.loadedID == entry.id)

        let pixel = try renderRows(renderer: renderer, device: device)
        #expect(pixel(4) == 0)
        #expect(pixel(32) == 255)
        #expect(pixel(60) == 0)
    }

    /// Renders a white 64x64 frame into rows 16..<48 of a 64x64 target; returns a row reader.
    private func renderRows(renderer: SlangFilterRenderer, device: MTLDevice) throws -> (Int) -> UInt8 {
        let size = 64
        func texture(_ usage: MTLTextureUsage) throws -> MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: size,
                                                                      height: size, mipmapped: false)
            descriptor.usage = usage
            descriptor.storageMode = .shared
            return try #require(device.makeTexture(descriptor: descriptor))
        }
        let source = try texture([.shaderRead])
        let white = [UInt8](repeating: 255, count: size * size * 4)
        source.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: white, bytesPerRow: size * 4)
        let target = try texture([.renderTarget, .shaderRead])

        let queue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(queue.makeCommandBuffer())
        let drew = renderer.render(source: source, commandBuffer: commandBuffer, target: target,
                                   contentRect: CGRect(x: 0, y: 16, width: 64, height: 32),
                                   flipVertically: false, linear: false)
        #expect(drew)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return { y in
            var out = [UInt8](repeating: 0, count: 4)
            target.getBytes(&out, bytesPerRow: size * 4, from: MTLRegionMake2D(32, y, 1, 1), mipmapLevel: 0)
            return out[0]
        }
    }
}

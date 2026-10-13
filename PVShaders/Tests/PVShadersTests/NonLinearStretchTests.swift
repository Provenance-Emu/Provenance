//
//  NonLinearStretchTests.swift
//  PVShadersTests
//

import Foundation
import Metal
import Testing
@testable import PVShaders

@Suite("NonLinearStretch")
struct NonLinearStretchTests {
    @Test("the curve keeps the edges and the centre fixed and never folds back")
    func curveIsMonotonic() {
        for stretch in [1.0, 4.0 / 3.0, 16.0 / 9.0 / (8.0 / 7.0), 3.0] {
            let slope = NonLinearStretchRenderer.centerSlope(stretch: stretch, amount: 1)
            #expect(slope < 1.5)
            #expect(NonLinearStretchRenderer.sourcePosition(forOutput: 1, centerSlope: slope) == 1)
            #expect(NonLinearStretchRenderer.sourcePosition(forOutput: -1, centerSlope: slope) == -1)
            #expect(NonLinearStretchRenderer.sourcePosition(forOutput: 0, centerSlope: slope) == 0)
            var previous: Float = -2
            for step in 0 ... 100 {
                let x = Float(step) / 50 - 1
                let u = NonLinearStretchRenderer.sourcePosition(forOutput: x, centerSlope: slope)
                #expect(u > previous)
                previous = u
            }
        }
    }

    @Test("amount 0 is a plain stretch; the full amount keeps the centre at its true aspect")
    func centerSlope() {
        #expect(NonLinearStretchRenderer.centerSlope(stretch: 4.0 / 3.0, amount: 0) == 1)
        #expect(abs(NonLinearStretchRenderer.centerSlope(stretch: 4.0 / 3.0, amount: 1) - 4.0 / 3.0) < 0.0001)
        #expect(NonLinearStretchRenderer.centerSlope(stretch: 3, amount: 1) == NonLinearStretchRenderer.maximumCenterSlope)
    }

    @Test("the warp pass renders")
    @MainActor
    func rendersOnGPU() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = NonLinearStretchRenderer(device: device)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 32, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = try #require(device.makeTexture(descriptor: descriptor))
        let source = try #require(renderer.intermediateTexture(matching: target))
        let commandBuffer = try #require(device.makeCommandQueue()?.makeCommandBuffer())
        #expect(renderer.encode(from: source, to: target, commandBuffer: commandBuffer, centerSlope: 1.3))
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        #expect(commandBuffer.error == nil)
    }
}

//
//  NonLinearStretchRenderer.swift
//  PVShaders
//
//  Non-linear horizontal stretch (issue #639): the picture fills the screen
//  width, but the sides absorb most of the stretch so the centre keeps close to
//  its true shape.
//
//  The frame is first drawn as a plain (linear) stretch into an intermediate
//  texture, filters included; one pass then remaps it horizontally. For an
//  output position x in [-1, 1] the source position is
//      u = a·x + (1 − a)·x³
//  which keeps both edges fixed (u(±1) = ±1). Its slope at the centre is `a`:
//  relative to a linear stretch by factor S, a = S shows the centre at its true
//  aspect. The slope at the edges is 3 − 2a, so the curve only stays monotonic
//  (no mirrored edges) while a < 1.5; `centerSlope` clamps below that.
//

import CoreGraphics
import Foundation
import Metal
import PVLogging

@MainActor
public final class NonLinearStretchRenderer {
    /// Largest centre slope used: the curve folds back at 1.5.
    nonisolated public static let maximumCenterSlope: Float = 1.45

    private let device: MTLDevice
    private var pipeline: MTLRenderPipelineState?
    private var pipelineFormat: MTLPixelFormat?
    private var sampler: MTLSamplerState?
    private var intermediate: MTLTexture?

    public init(device: MTLDevice) {
        self.device = device
    }

    /// Centre slope `a` for a picture stretched by `stretch` (container aspect /
    /// picture aspect), scaled by `amount` (0 = linear stretch, 1 = full effect).
    nonisolated public static func centerSlope(stretch: CGFloat, amount: Float) -> Float {
        let target = min(max(Float(stretch), 1), maximumCenterSlope)
        let clampedAmount = min(max(amount, 0), 1)
        return 1 + (target - 1) * clampedAmount
    }

    /// Source position (in [-1, 1]) shown at output position `x` (in [-1, 1]).
    nonisolated public static func sourcePosition(forOutput x: Float, centerSlope a: Float) -> Float {
        a * x + (1 - a) * x * x * x
    }

    /// A private texture matching `target`'s size and format to draw the linear stretch into.
    public func intermediateTexture(matching target: MTLTexture) -> MTLTexture? {
        if let intermediate, intermediate.width == target.width, intermediate.height == target.height,
           intermediate.pixelFormat == target.pixelFormat {
            return intermediate
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: target.pixelFormat,
                                                                  width: target.width,
                                                                  height: target.height,
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        intermediate = device.makeTexture(descriptor: descriptor)
        return intermediate
    }

    /// Encodes the warp from `source` (a linear stretch) into `target`.
    @discardableResult
    public func encode(from source: MTLTexture, to target: MTLTexture,
                       commandBuffer: MTLCommandBuffer, centerSlope: Float) -> Bool {
        guard let pipeline = pipeline(for: target.pixelFormat), let sampler = makeSamplerIfNeeded() else {
            return false
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.label = "Non-linear stretch"
        encoder.setRenderPipelineState(pipeline)
        var slope = centerSlope
        encoder.setFragmentBytes(&slope, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }

    private func makeSamplerIfNeeded() -> MTLSamplerState? {
        if let sampler { return sampler }
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        sampler = device.makeSamplerState(descriptor: descriptor)
        return sampler
    }

    private func pipeline(for format: MTLPixelFormat) -> MTLRenderPipelineState? {
        if let pipeline, pipelineFormat == format { return pipeline }
        do {
            // Small enough to compile from source once; keeps it out of the package metallib,
            // which the SwiftPM command line does not build.
            let library = try device.makeLibrary(source: Self.source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "nonlinear_stretch_vs")
            descriptor.fragmentFunction = library.makeFunction(name: "nonlinear_stretch_fs")
            descriptor.colorAttachments[0].pixelFormat = format
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            pipelineFormat = format
        } catch {
            ELOG("Non-linear stretch pipeline failed: \(error)")
            pipeline = nil
        }
        return pipeline
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct StretchOut {
        float4 position [[position]];
        float2 uv;
    };

    // One triangle covering the target; uv (0,0) is the top-left corner.
    vertex StretchOut nonlinear_stretch_vs(uint vid [[vertex_id]]) {
        float2 uv = float2((vid << 1) & 2, vid & 2);
        StretchOut out;
        out.position = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
        out.uv = uv;
        return out;
    }

    fragment float4 nonlinear_stretch_fs(StretchOut in [[stage_in]],
                                         constant float &centerSlope [[buffer(0)]],
                                         texture2d<float> source [[texture(0)]],
                                         sampler linearSampler [[sampler(0)]]) {
        float x = in.uv.x * 2.0 - 1.0;
        float u = centerSlope * x + (1.0 - centerSlope) * x * x * x;
        return source.sample(linearSampler, float2(u * 0.5 + 0.5, in.uv.y));
    }
    """
}

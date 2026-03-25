// PVMetalViewController+DualScreen.swift
// PVUI
//
// GPU-side dual-screen rendering for systems like the Nintendo DS.
//
// The DS outputs a combined 256×384 framebuffer where the top screen occupies
// rows 0–191 and the bottom screen occupies rows 192–383.  This extension
// teaches PVMetalViewController to split that texture into two independently-
// positioned viewports in a single Metal render pass, using the destination
// rectangles supplied by the skin system.
//
// Usage
// -----
// 1. Set `dualScreenLayout` to an array of `DualScreenRenderInfo` values
//    (one per visible screen), populated from the active DeltaSkin.
// 2. The next call to `directRender` automatically routes through
//    `renderDualScreenLayout` instead of the standard fullscreen blit.
// 3. Clear `dualScreenLayout` (set to nil) to resume single-screen rendering.

import Metal
import MetalKit
import simd
import CoreGraphics
import PVLogging

// MARK: - DualScreenRenderInfo

/// Describes how one sub-screen should be sampled and displayed by the Metal renderer.
///
/// - `normalizedSourceRect`: which region of the *combined* input texture to sample
///   (0…1 in both axes).  For a 256×384 DS framebuffer the defaults are:
///   - top screen:    `CGRect(x: 0, y: 0,   width: 1, height: 0.5)`
///   - bottom screen: `CGRect(x: 0, y: 0.5, width: 1, height: 0.5)`
///
/// - `viewDestRect`: where to paint the result, expressed in the MTKView's
///   UIKit-point coordinate space.  The renderer converts to NDC at draw time
///   so it stays correct regardless of the drawable's `contentScaleFactor`.
public struct DualScreenRenderInfo: Sendable {
    /// Normalized (0…1) source sub-rectangle inside the combined input texture.
    public let normalizedSourceRect: CGRect
    /// Destination in the Metal view's UIKit-point coordinate space.
    public let viewDestRect: CGRect

    public init(normalizedSourceRect: CGRect, viewDestRect: CGRect) {
        self.normalizedSourceRect = normalizedSourceRect
        self.viewDestRect = viewDestRect
    }
}

// MARK: - PVMetalViewController + dual-screen rendering

extension PVMetalViewController {

    // MARK: Inline Metal source

    /// Metal source for the dual-screen sub-rectangle blit shaders.
    ///
    /// Compiled at runtime so we don't need to load from a bundle — matches the
    /// pattern already used by `createBasicShaders()`.
    static let dualScreenShaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct DSVSOut {
        float4 position [[position]];
        float2 texCoord;
    };

    // buffer(0): array of float4 (NDC.xy, UV.zw) for a 4-vertex triangle strip
    vertex DSVSOut dual_screen_vs(
        uint             vid      [[vertex_id]],
        constant float4 *vertices [[buffer(0)]])
    {
        DSVSOut out;
        out.position = float4(vertices[vid].xy, 0.0f, 1.0f);
        out.texCoord = vertices[vid].zw;
        return out;
    }

    fragment half4 dual_screen_ps(
        DSVSOut         in     [[stage_in]],
        texture2d<half> source [[texture(0)]],
        sampler         samp   [[sampler(0)]])
    {
        half4 c = source.sample(samp, in.texCoord);
        c.a = 1.0h;
        return c;
    }
    """

    // MARK: Pipeline setup

    /// Compiles and caches the dual-screen blit pipeline.
    /// Safe to call multiple times; no-ops when the pipeline already exists.
    func buildDualScreenBlitPipelineIfNeeded() {
        guard dualScreenBlitPipeline == nil else { return }
        guard let device = device else {
            ELOG("dual-screen: cannot build pipeline – Metal device is nil")
            return
        }

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.dualScreenShaderSource, options: nil)
        } catch {
            ELOG("dual-screen: shader compile error: \(error)")
            return
        }

        guard let vertFn = library.makeFunction(name: "dual_screen_vs"),
              let fragFn = library.makeFunction(name: "dual_screen_ps") else {
            ELOG("dual-screen: shader functions missing from compiled library")
            return
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vertFn
        desc.fragmentFunction = fragFn
        desc.colorAttachments[0].pixelFormat = mtlView.colorPixelFormat

        do {
            dualScreenBlitPipeline = try device.makeRenderPipelineState(descriptor: desc)
            ILOG("dual-screen: render pipeline ready")
        } catch {
            ELOG("dual-screen: pipeline creation failed: \(error)")
        }
    }

    // MARK: Per-frame rendering

    /// Renders each entry of `dualScreenLayout` as a sub-rectangle blit of
    /// `sourceTexture` inside the provided render encoder.
    ///
    /// All screens are encoded in a **single render pass** for efficiency;
    /// only the vertex data changes between draw calls.
    ///
    /// - Parameters:
    ///   - encoder:      Active render command encoder already bound to the current drawable.
    ///   - sourceTexture: The combined emulator framebuffer (e.g. 256×384 for DS).
    ///   - drawableSize:  Pixel dimensions of the current drawable.
    ///   - flipY:         Pass `true` when `sourceTexture` has OpenGL/bottom-up origin.
    func renderDualScreenLayout(encoder:       MTLRenderCommandEncoder,
                                 sourceTexture: MTLTexture,
                                 drawableSize:  CGSize,
                                 flipY:         Bool) {
        guard let layout = dualScreenLayout, !layout.isEmpty else { return }

        buildDualScreenBlitPipelineIfNeeded()
        guard let pipeline = dualScreenBlitPipeline else {
            ELOG("dual-screen: pipeline unavailable, skipping dual-screen render")
            return
        }

        let sampler = renderSettings.smoothingEnabled ? linearSampler : pointSampler
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        if let sampler { encoder.setFragmentSamplerState(sampler, index: 0) }

        let dw = Float(drawableSize.width)
        let dh = Float(drawableSize.height)
        let scale = Float(mtlView.contentScaleFactor)

        for info in layout {
            // Destination in drawable-pixel space
            let px0 = Float(info.viewDestRect.minX) * scale
            let px1 = Float(info.viewDestRect.maxX) * scale
            let py0 = Float(info.viewDestRect.minY) * scale
            let py1 = Float(info.viewDestRect.maxY) * scale

            // Convert to NDC  (Metal: x ∈ [-1,+1], y ∈ [-1,+1] with +1 = top)
            let nx0 = (2.0 * px0 / dw) - 1.0
            let nx1 = (2.0 * px1 / dw) - 1.0
            let ny0 = 1.0 - (2.0 * py0 / dh)   // top edge in Metal NDC
            let ny1 = 1.0 - (2.0 * py1 / dh)   // bottom edge in Metal NDC

            // Source UV  — flip V for OpenGL-origin textures
            let u0 = Float(info.normalizedSourceRect.minX)
            let u1 = Float(info.normalizedSourceRect.maxX)
            let v0 = flipY ? Float(info.normalizedSourceRect.maxY)
                           : Float(info.normalizedSourceRect.minY)
            let v1 = flipY ? Float(info.normalizedSourceRect.minY)
                           : Float(info.normalizedSourceRect.maxY)

            // Triangle-strip quad: top-left, top-right, bottom-left, bottom-right
            var vertices: [SIMD4<Float>] = [
                SIMD4(nx0, ny0, u0, v0),
                SIMD4(nx1, ny0, u1, v0),
                SIMD4(nx0, ny1, u0, v1),
                SIMD4(nx1, ny1, u1, v1),
            ]

            encoder.setVertexBytes(&vertices,
                                   length: vertices.count * MemoryLayout<SIMD4<Float>>.stride,
                                   index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
    }
}

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
/// - `sourceRect`: which region of the core's *combined* framebuffer to sample, in
///   native (1x) pixels of a framebuffer of `framebufferSize`. For the default
///   stacked 256×384 DS framebuffer:
///   - top screen:    `CGRect(x: 0, y: 0,   width: 256, height: 192)`
///   - bottom screen: `CGRect(x: 0, y: 192, width: 256, height: 192)`
///   It is normalised against the bound texture every frame (see
///   `DualScreenSourceMapping.normalizedSourceRect`), because the texture is only
///   resized to the core's real geometry after the layout is installed.
///
/// - `viewDestRect`: where to paint the result, expressed in the MTKView's
///   UIKit-point coordinate space.  The renderer converts to NDC at draw time
///   so it stays correct regardless of the drawable's `contentScaleFactor`.
struct DualScreenRenderInfo: Sendable {
    /// Source sub-rectangle in native framebuffer pixels.
    let sourceRect: CGRect
    /// Native size of the whole framebuffer `sourceRect` lives in.
    let framebufferSize: CGSize
    /// Destination in the Metal view's UIKit-point coordinate space.
    let viewDestRect: CGRect
}

/// Result of one `renderDualScreenLayout` call.
enum DualScreenRenderOutcome {
    /// Every screen was encoded.
    case drawn
    /// Nothing was encoded because the bound texture does not have the layout's
    /// proportions yet (e.g. a thin core still on its pre-boot fallback geometry).
    /// Transient: the caller should draw a plain blit for this frame only.
    case textureMismatch
    /// No layout, or the pipeline could not be built.
    case unavailable
}

// MARK: - PVMetalViewController + dual-screen rendering

extension PVMetalViewController {

    // MARK: Inline Metal source

    /// Metal source for the dual-screen sub-rectangle blit shaders.
    ///
    /// The canonical source lives in
    /// `PVShaders/Sources/PVShaders/Resources/Metal/Blitters/dual_screen_blit.metal`.
    /// That file is compiled into the PVShaders bundle's metallib during the Xcode
    /// build, but loading it at runtime requires explicit bundle access across the
    /// module boundary.  To avoid that coupling (and to match the pattern used by
    /// every other shader in PVMetalViewController) we embed an identical copy here
    /// and compile it at runtime via `device.makeLibrary(source:)`.
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
        texture2d<half> source [[texture(0)]])
    {
        constexpr sampler s(coord::normalized,
                            address::clamp_to_edge,
                            filter::linear);
        half4 c = source.sample(s, in.texCoord);
        c.a = 1.0h;
        return c;
    }
    """

    // MARK: Pipeline setup

    /// Compiles and caches the dual-screen blit pipeline.
    /// Safe to call multiple times; no-ops when the pipeline already exists or after a build failure.
    func buildDualScreenBlitPipelineIfNeeded() {
        guard dualScreenBlitPipeline == nil else { return }
        // Skip retry after a failure to avoid per-frame shader compilation attempts.
        guard !dualScreenPipelineBuildFailed else { return }
        guard let device = device else {
            ELOG("dual-screen: cannot build pipeline – Metal device is nil")
            dualScreenPipelineBuildFailed = true
            return
        }

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.dualScreenShaderSource, options: nil)
        } catch {
            ELOG("dual-screen: shader compile error: \(error)")
            dualScreenPipelineBuildFailed = true
            return
        }

        guard let vertFn = library.makeFunction(name: "dual_screen_vs"),
              let fragFn = library.makeFunction(name: "dual_screen_ps") else {
            ELOG("dual-screen: shader functions missing from compiled library")
            dualScreenPipelineBuildFailed = true
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
            dualScreenPipelineBuildFailed = true
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
    ///   - sourceIsBottomUp: Pass `true` when `sourceTexture` stores its image bottom
    ///                       row first (OpenGL / IOSurface frames).
    /// - Returns: `.drawn` when every screen was encoded. Otherwise nothing was
    ///   encoded and the caller should fall back to the standard fullscreen blit to
    ///   avoid presenting a black frame.
    func renderDualScreenLayout(encoder:          MTLRenderCommandEncoder,
                                sourceTexture:    MTLTexture,
                                drawableSize:     CGSize,
                                sourceIsBottomUp: Bool) -> DualScreenRenderOutcome {
        guard let layout = dualScreenLayout, !layout.isEmpty else { return .unavailable }

        buildDualScreenBlitPipelineIfNeeded()
        guard let pipeline = dualScreenBlitPipeline else {
            ELOG("dual-screen: pipeline unavailable, skipping dual-screen render")
            return .unavailable
        }

        // Normalise every source rect against the texture actually bound before
        // encoding anything, so a mismatch leaves the encoder untouched.
        let textureSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
        var sources: [DualScreenTextureCoordinates] = []
        for info in layout {
            guard let normalized = DualScreenSourceMapping.normalizedSourceRect(
                info.sourceRect, framebufferSize: info.framebufferSize, textureSize: textureSize) else {
                return .textureMismatch
            }
            sources.append(DualScreenSourceMapping.textureCoordinates(for: normalized,
                                                                     sourceIsBottomUp: sourceIsBottomUp))
        }

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(sourceTexture, index: 0)

        let dw = Float(drawableSize.width)
        let dh = Float(drawableSize.height)
        let scale = Float(mtlView.contentScaleFactor)

        for (info, source) in zip(layout, sources) {
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

            // Triangle-strip quad: top-left, top-right, bottom-left, bottom-right
            var vertices: [SIMD4<Float>] = [
                SIMD4(nx0, ny0, source.u0, source.vTop),
                SIMD4(nx1, ny0, source.u1, source.vTop),
                SIMD4(nx0, ny1, source.u0, source.vBottom),
                SIMD4(nx1, ny1, source.u1, source.vBottom)
            ]

            let byteLength = vertices.count * MemoryLayout<SIMD4<Float>>.stride
            vertices.withUnsafeBytes { ptr in
                encoder.setVertexBytes(ptr.baseAddress!, length: byteLength, index: 0)
            }
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        return .drawn
    }
}

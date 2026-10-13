// PVMetalViewController+DualScreenFilters.swift
// PVUI
//
// Filters for dual-screen layouts (DS skins): each screen's skin filters and the
// handheld-LCD look. The Metal filters never run there, so Core Image composes
// every screen into a drawable-sized texture, and one quad copies it into the
// drawable (which is framebuffer-only, so Core Image cannot write it directly).
//
// A screen's skin filters always run here. Shaders cannot draw on dual-screen
// layouts, so a shader selection must not silence them as it does for the
// single-screen picture.

import CoreImage
import Metal
import QuartzCore
import simd
import PVShaders

extension PVMetalViewController {

    /// The next dual-screen frame goes through Core Image: a screen has skin filters, or
    /// the LCD look is on for a screen without them.
    var drawsDualScreenWithFilters: Bool {
        dualScreenLayout?.contains { $0.skinProvidesFilter || renderSettings.dualScreenLCDLook } ?? false
    }

    /// Encodes the dual-screen layout with skin filters and the LCD look. Must run before
    /// any render encoder is open on `commandBuffer`, because Core Image encodes its own passes.
    /// - Returns: `false` when nothing reached the drawable (no layout yet, the texture
    ///   lacks the layout's proportions, Core Image cannot read it); draw the plain
    ///   dual-screen path instead.
    func renderDualScreenWithFilters(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable,
                                     sourceTexture: MTLTexture, sourceIsBottomUp: Bool) -> Bool {
        guard let layout = dualScreenLayout, !layout.isEmpty, let device else { return false }
        buildDualScreenBlitPipelineIfNeeded()
        let textureSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
        guard let pipeline = dualScreenBlitPipeline,
              let coordinates = DualScreenSourceMapping.textureCoordinates(for: layout, textureSize: textureSize,
                                                                           sourceIsBottomUp: sourceIsBottomUp),
              let target = dualScreenLCDTarget(matching: drawable.texture, device: device) else { return false }

        let scale = mtlView.contentScaleFactor
        let lcdLook = renderSettings.dualScreenLCDLook
        let placements = zip(layout, coordinates).map { info, coordinates in
            DualScreenSourceMapping.lcdPlacement(for: info, coordinates: coordinates, textureSize: textureSize,
                                                 contentScale: scale, lcdLook: lcdLook)
        }
        let screenFilters: [ScreenImageFilter?] = layout.indices.map { index in
            guard index < dualScreenSkinFilters.count, !dualScreenSkinFilters[index].isEmpty else { return nil }
            let filters = dualScreenSkinFilters[index]
            return { DeltaSkinScreenFilter.run(filters, on: $0) }
        }
        guard dualScreenLCDComposer.render(source: sourceTexture, placements: placements, into: target,
                                           context: sharedFrameFilterContext(device: device),
                                           commandBuffer: commandBuffer,
                                           screenFilters: screenFilters) else { return false }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(target, index: 0)
        // Whole drawable, (NDC.xy, UV.zw); v = 0 is the composed frame's first row.
        var quad: [SIMD4<Float>] = [SIMD4(-1, 1, 0, 0), SIMD4(1, 1, 1, 0), SIMD4(-1, -1, 0, 1), SIMD4(1, -1, 1, 1)]
        encoder.setVertexBytes(&quad, length: MemoryLayout<SIMD4<Float>>.stride * quad.count, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: quad.count)
        encoder.endEncoding()
        return true
    }

    /// The composed frame, reused while the drawable keeps its size.
    private func dualScreenLCDTarget(matching drawable: MTLTexture, device: MTLDevice) -> MTLTexture? {
        if let texture = dualScreenLCDTexture, texture.width == drawable.width, texture.height == drawable.height {
            return texture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: drawable.width,
                                                                  height: drawable.height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private
        dualScreenLCDTexture = device.makeTexture(descriptor: descriptor)
        return dualScreenLCDTexture
    }
}

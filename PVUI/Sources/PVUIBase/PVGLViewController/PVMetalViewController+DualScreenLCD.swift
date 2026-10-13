// PVMetalViewController+DualScreenLCD.swift
// PVUI
//
// Handheld-LCD look for dual-screen layouts (DS skins). The Metal filters never
// run there, so Core Image composes every screen with `LCDScreenFilter` into a
// drawable-sized texture, and one quad copies it into the drawable (which is
// framebuffer-only, so Core Image cannot write it directly).

import CoreImage
import Metal
import QuartzCore
import simd
import PVShaders

extension PVMetalViewController {

    /// The next dual-screen frame takes the LCD path: the setting is on and at least
    /// one screen has no skin filter of its own.
    var drawsDualScreenLCDLook: Bool {
        renderSettings.dualScreenLCDLook && (dualScreenLayout?.contains { !$0.skinProvidesFilter } ?? false)
    }

    /// Encodes the dual-screen layout with the LCD look. Must run before any render
    /// encoder is open on `commandBuffer`, because Core Image encodes its own passes.
    /// - Returns: `false` when nothing reached the drawable (no layout yet, the texture
    ///   lacks the layout's proportions, Core Image cannot read it); draw the plain
    ///   dual-screen path instead.
    func renderDualScreenLCD(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable,
                             sourceTexture: MTLTexture, sourceIsBottomUp: Bool) -> Bool {
        guard let layout = dualScreenLayout, !layout.isEmpty, let device else { return false }
        buildDualScreenBlitPipelineIfNeeded()
        let textureSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
        guard let pipeline = dualScreenBlitPipeline,
              let coordinates = DualScreenSourceMapping.textureCoordinates(for: layout, textureSize: textureSize,
                                                                           sourceIsBottomUp: sourceIsBottomUp),
              let target = dualScreenLCDTarget(matching: drawable.texture, device: device) else { return false }

        let scale = mtlView.contentScaleFactor
        let placements = zip(layout, coordinates).map { info, coordinates in
            DualScreenSourceMapping.lcdPlacement(for: info, coordinates: coordinates, textureSize: textureSize,
                                                 contentScale: scale)
        }
        let context = dualScreenLCDContext ?? LCDScreenComposer.makeContext(device: device)
        dualScreenLCDContext = context
        guard dualScreenLCDComposer.render(source: sourceTexture, placements: placements, into: target,
                                           context: context, commandBuffer: commandBuffer) else { return false }

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

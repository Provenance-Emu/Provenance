// PVMetalViewController+SkinFilter.swift
// PVUI
//
// A DeltaSkin's own screen filters (the `filters` of its game screen). Core
// Image runs them over the core's frame at native resolution, the right way up,
// as Delta does, into a texture the normal blit then draws.

import CoreImage
import Metal
import PVShaders

extension PVMetalViewController {

    /// The input frame with the skin's filters applied, or `nil` to draw the frame as is
    /// (no skin filters, or Core Image could not read the texture). Must run before any
    /// render encoder is open on `commandBuffer`, because Core Image encodes its own passes.
    /// - Parameter storedTopRowFirst: the texture holds the picture's top row first
    ///   (software and Vulkan frames); `false` for OpenGL frames.
    func skinFilteredFrame(from source: MTLTexture, storedTopRowFirst: Bool,
                           commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard !skinScreenFilters.isEmpty, let device,
              let image = FrameImageFilter.image(of: source),
              let target = skinFilterTarget(matching: source, device: device) else { return nil }
        let filters = skinScreenFilters
        let filtered = FrameImageFilter.apply({ DeltaSkinScreenFilter.run(filters, on: $0) }, to: image,
                                              storedTopRowFirst: storedTopRowFirst)
        let rendered = FrameImageFilter.render(filtered, into: target, context: sharedFrameFilterContext(device: device),
                                               commandBuffer: commandBuffer)
        return rendered ? target : nil
    }

    /// The colour-passthrough Core Image context shared by skin filters and the LCD look.
    func sharedFrameFilterContext(device: MTLDevice) -> CIContext {
        if let frameFilterContext { return frameFilterContext }
        let context = FrameImageFilter.makeContext(device: device)
        frameFilterContext = context
        return context
    }

    /// The filtered frame, reused while the core's frame keeps its size.
    private func skinFilterTarget(matching source: MTLTexture, device: MTLDevice) -> MTLTexture? {
        if let texture = skinFilterTexture, texture.width == source.width, texture.height == source.height {
            return texture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: source.width,
                                                                  height: source.height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private
        skinFilterTexture = device.makeTexture(descriptor: descriptor)
        return skinFilterTexture
    }
}

extension DeltaSkinScreenFilter {
    /// Each dual-screen screen's skin filters, in skin order.
    static func chains(for layout: [DualScreenRenderInfo]) -> [[DeltaSkinScreenFilter]] {
        layout.map { $0.skinFilterInfos.compactMap(DeltaSkinScreenFilter.init(filterInfo:)) }
    }

    /// Runs `filters` over `image` in order, as Delta chains a screen's filters. Each
    /// filter lets go of its input afterwards so it does not keep the frame alive.
    static func run(_ filters: [DeltaSkinScreenFilter], on image: CIImage) -> CIImage {
        filters.reduce(image) { current, screenFilter in
            defer { screenFilter.filter.setValue(nil, forKey: kCIInputImageKey) }
            return screenFilter.apply(to: current, in: current.extent) ?? current
        }
    }
}

//
//  FrameImageFilter.swift
//  PVShaders
//
//  Core Image over emulator frames held in Metal textures. Core Image reads row r
//  of a texture as y = r and writes y = r back to row r, so a texture round trip
//  needs no flip. Filters, though, expect y to grow upwards (a blur's centre, a
//  vignette's offset), so frames are turned upright before filtering.
//

import CoreGraphics
import CoreImage
import Metal

public enum FrameImageFilter {
    /// A context that passes colours through untouched, so filtered frames match the
    /// plain blit apart from the filter itself.
    public static func makeContext(device: MTLDevice) -> CIContext {
        CIContext(mtlDevice: device, options: [
            .workingColorSpace: NSNull(),
            .outputColorSpace: NSNull(),
            .cacheIntermediates: false
        ])
    }

    /// Runs `filter` over a frame read from a texture, the right way up.
    /// - Parameters:
    ///   - image: the texture's image (row 0 at y = 0).
    ///   - storedTopRowFirst: row 0 is the picture's top row (software and Vulkan
    ///     frames); `false` for OpenGL frames, which store the bottom row first.
    /// - Returns: the filtered frame in the same storage order and extent, opaque.
    public static func apply(_ filter: (CIImage) -> CIImage?, to image: CIImage,
                             storedTopRowFirst: Bool) -> CIImage {
        let extent = image.extent
        guard !extent.isInfinite, !extent.isEmpty else { return image }
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: extent.minY + extent.maxY)
        let upright = storedTopRowFirst ? image.transformed(by: flip) : image
        let filtered = opaque(filter(upright) ?? upright, in: extent)
        return storedTopRowFirst ? filtered.transformed(by: flip).cropped(to: extent) : filtered
    }

    /// `image` cropped to `extent` over opaque black, so a filter that grows the extent
    /// or thins the edges (a blur) never leaves see-through pixels in the picture.
    public static func opaque(_ image: CIImage, in extent: CGRect) -> CIImage {
        image.cropped(to: extent).composited(over: CIImage(color: .black).cropped(to: extent))
    }

    /// Encodes `image` into `target` on `commandBuffer` (y = r lands in row r).
    /// - Returns: `false` when Core Image could not start the render.
    @discardableResult
    public static func render(_ image: CIImage, into target: MTLTexture, context: CIContext,
                              commandBuffer: MTLCommandBuffer) -> Bool {
        let destination = CIRenderDestination(mtlTexture: target, commandBuffer: commandBuffer)
        destination.colorSpace = nil
        do {
            try context.startTask(toRender: image, to: destination)
            return true
        } catch {
            return false
        }
    }

    /// The texture's image as Core Image sees it, without colour management.
    public static func image(of texture: MTLTexture) -> CIImage? {
        CIImage(mtlTexture: texture, options: [.colorSpace: NSNull()])
    }
}

//
//  LCDScreenFilter.swift
//  PVShaders
//
//  A handheld-LCD look built from stock Core Image filters, for screens the
//  Metal filters cannot reach (dual-screen DS / 3DS layouts, which skins draw
//  per screen through CIFilters). Not wired yet: see the dual-screen LCD note
//  in docs/RELEASE_SMOKE_TESTS.md.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Darkens the gaps between emulated pixels, slightly softens the image (LCD
/// response) and mutes colours, like a DS / 3DS panel.
///
/// Set `inputPixelPitch` to the size of one emulated pixel in output pixels
/// (output width / native width); the grid lines fall on those boundaries.
public final class LCDScreenFilter: CIFilter {
    /// Default values; also the ranges a settings UI should offer.
    public enum Defaults {
        public static let gridStrength: CGFloat = 0.35   // 0...1
        public static let ghosting: CGFloat = 0.6        // blur radius in output pixels, 0...3
        public static let saturation: CGFloat = 0.85     // 0...2
        public static let brightness: CGFloat = 0.03     // -0.5...0.5
    }

    /// Below this pitch the grid would alias into moiré, so it is skipped.
    static let minimumPitchForGrid: CGFloat = 2

    @objc public var inputImage: CIImage?
    /// Output pixels per emulated pixel.
    @objc public var inputPixelPitch: CGFloat = 3
    @objc public var inputGridStrength: CGFloat = Defaults.gridStrength
    @objc public var inputGhosting: CGFloat = Defaults.ghosting
    @objc public var inputSaturation: CGFloat = Defaults.saturation
    @objc public var inputBrightness: CGFloat = Defaults.brightness

    override public var outputImage: CIImage? {
        guard let input = inputImage else { return nil }
        let extent = input.extent
        guard !extent.isInfinite, !extent.isEmpty else { return input }

        var image = input
        if inputGhosting > 0 {
            image = image.clampedToExtent()
                .applyingGaussianBlur(sigma: Double(inputGhosting))
                .cropped(to: extent)
        }
        image = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: inputSaturation,
            kCIInputBrightnessKey: inputBrightness,
            kCIInputContrastKey: 1.0
        ])
        guard inputGridStrength > 0, inputPixelPitch >= Self.minimumPitchForGrid,
              let grid = gridMask(extent: extent) else {
            return image
        }
        return image.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: grid])
            .cropped(to: extent)
    }

    /// Cells per emulated pixel in the grid tile; the last row and column are the gap,
    /// so gaps are a quarter of a pixel wide.
    static let tileCells = 4

    /// White everywhere except darker gaps along every emulated-pixel boundary.
    func gridMask(extent: CGRect) -> CIImage? {
        let cells = Self.tileCells
        let gapValue = UInt8((1 - min(max(inputGridStrength, 0), 1)) * 255)
        var pixels = [UInt8](repeating: 255, count: cells * cells * 4)
        for y in 0 ..< cells {
            for x in 0 ..< cells where x == cells - 1 || y == cells - 1 {
                let i = (y * cells + x) * 4
                pixels[i] = gapValue
                pixels[i + 1] = gapValue
                pixels[i + 2] = gapValue
            }
        }
        let tile = CIImage(bitmapData: Data(pixels), bytesPerRow: cells * 4,
                           size: CGSize(width: cells, height: cells), format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())
            .samplingNearest()
        let scale = inputPixelPitch / CGFloat(cells)
        let placement = CGAffineTransform(translationX: extent.minX, y: extent.minY).scaledBy(x: scale, y: scale)
        let tiler = CIFilter.affineTile()
        tiler.inputImage = tile
        tiler.transform = placement
        return tiler.outputImage?.cropped(to: extent)
    }
}

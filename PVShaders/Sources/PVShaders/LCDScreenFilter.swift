//
//  LCDScreenFilter.swift
//  PVShaders
//
//  A handheld-LCD look built from stock Core Image filters, for screens the
//  Metal filters cannot reach (dual-screen DS / 3DS layouts). DS skins run it
//  per screen through `LCDScreenComposer`; Azahar draws into its own layer, so
//  3DS gets only the grid, drawn over each screen from `gapRects`.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Darkens the gaps between emulated pixels, slightly softens the image (LCD
/// response) and mutes colours, like a DS / 3DS panel.
///
/// Set `inputPixelPitch` to the size of one emulated pixel in output pixels
/// (output width / native width); the grid lines fall on those boundaries.
/// `inputPixelPitchY` covers screens stretched to another aspect (0 = square pixels).
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
    /// Output pixels per emulated pixel vertically; 0 uses `inputPixelPitch`.
    @objc public var inputPixelPitchY: CGFloat = 0
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
        guard inputGridStrength > 0, min(inputPixelPitch, pitchY) >= Self.minimumPitchForGrid,
              let grid = gridMask(extent: extent) else {
            return image
        }
        return image.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: grid])
            .cropped(to: extent)
    }

    /// Cells per emulated pixel in the grid tile; the last row and column are the gap,
    /// so gaps are a quarter of a pixel wide.
    static let tileCells = 4

    private var pitchY: CGFloat { inputPixelPitchY > 0 ? inputPixelPitchY : inputPixelPitch }

    /// The last tile built, keyed by its gap value; `outputImage` runs every frame.
    private var cachedTile: (gapValue: UInt8, image: CIImage)?

    /// White everywhere except darker gaps along every emulated-pixel boundary.
    func gridMask(extent: CGRect) -> CIImage? {
        let cells = Self.tileCells
        let tile = gridTile(gapValue: UInt8((1 - min(max(inputGridStrength, 0), 1)) * 255))
        let placement = CGAffineTransform(translationX: extent.minX, y: extent.minY)
            .scaledBy(x: inputPixelPitch / CGFloat(cells), y: pitchY / CGFloat(cells))
        let tiler = CIFilter.affineTile()
        tiler.inputImage = tile
        tiler.transform = placement
        return tiler.outputImage?.cropped(to: extent)
    }

    private func gridTile(gapValue: UInt8) -> CIImage {
        if let cachedTile, cachedTile.gapValue == gapValue { return cachedTile.image }
        let cells = Self.tileCells
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
        cachedTile = (gapValue, tile)
        return tile
    }

    /// The grid's gaps for a screen of `size` showing `nativeSize` emulated pixels: one
    /// column per pixel on its trailing edge and one row on its far edge, a quarter of a
    /// pixel wide, like the filter's grid. Fill them all as one path so crossings are not
    /// darkened twice. Empty when a pixel would cover fewer than `minimumPitchForGrid`
    /// device pixels at `scale`.
    public static func gapRects(in size: CGSize, nativeSize: CGSize, scale: CGFloat) -> [CGRect] {
        guard nativeSize.width >= 1, nativeSize.height >= 1, size.width > 0, size.height > 0 else { return [] }
        let columns = Int(nativeSize.width), rows = Int(nativeSize.height)
        let pitchX = size.width / CGFloat(columns), pitchY = size.height / CGFloat(rows)
        guard min(pitchX, pitchY) * scale >= minimumPitchForGrid else { return [] }
        let gapX = pitchX / CGFloat(tileCells), gapY = pitchY / CGFloat(tileCells)
        let columnRects = (1 ... columns).map {
            CGRect(x: CGFloat($0) * pitchX - gapX, y: 0, width: gapX, height: size.height)
        }
        let rowRects = (1 ... rows).map {
            CGRect(x: 0, y: CGFloat($0) * pitchY - gapY, width: size.width, height: gapY)
        }
        return columnRects + rowRects
    }
}

//
//  LCDScreenComposer.swift
//  PVShaders
//
//  Draws the screens of a dual-screen layout (DS skins) into one frame. Each
//  screen can run its skin's own filters, upright at native resolution, and
//  `LCDScreenFilter` at output resolution so the grid falls on its pixels.
//
//  Coordinates are texture rows (see `FrameImageFilter`): y grows downwards
//  here, as in the drawable.
//

import CoreGraphics
import CoreImage
import Metal

/// One screen of a dual-screen frame.
public struct LCDScreenPlacement: Equatable, Sendable {
    /// The screen's region of the source texture, in texture pixels (row 0 at y = 0).
    public var sourceRect: CGRect
    /// The region stores the screen bottom row first (OpenGL frames).
    public var sourceIsFlipped: Bool
    /// Where the screen goes in the target, in target pixels (row 0 at y = 0).
    public var destinationRect: CGRect
    /// Emulated pixels across and down the screen; sets the grid pitch.
    public var nativeSize: CGSize
    /// `false` draws the screen plain (its skin brings its own filter).
    public var appliesLCD: Bool

    public init(sourceRect: CGRect, sourceIsFlipped: Bool, destinationRect: CGRect,
                nativeSize: CGSize, appliesLCD: Bool) {
        self.sourceRect = sourceRect
        self.sourceIsFlipped = sourceIsFlipped
        self.destinationRect = destinationRect
        self.nativeSize = nativeSize
        self.appliesLCD = appliesLCD
    }
}

/// A screen's own filters, run on the upright screen image (origin at zero, native size).
public typealias ScreenImageFilter = (CIImage) -> CIImage?

/// Composes dual-screen frames. Keeps one LCD filter per screen across frames, so use
/// one instance from one thread.
public final class LCDScreenComposer {
    private var filters: [LCDScreenFilter] = []

    public init() {}

    /// The whole frame: black, with every placed screen drawn over it in order.
    /// - Parameter screenFilters: per placement, the skin filters to run first (`nil` for none).
    public func compose(source: CIImage, placements: [LCDScreenPlacement], canvas: CGRect,
                        screenFilters: [ScreenImageFilter?] = []) -> CIImage {
        while filters.count < placements.count { filters.append(LCDScreenFilter()) }
        var frame = CIImage(color: .black).cropped(to: canvas)
        for (index, (placement, filter)) in zip(placements, filters).enumerated() {
            let screenFilter = index < screenFilters.count ? screenFilters[index] : nil
            guard let screen = place(source: source, placement, filter: screenFilter) else { continue }
            var output = screen
            if placement.appliesLCD {
                filter.inputImage = screen
                filter.inputPixelPitch = placement.destinationRect.width / placement.nativeSize.width
                filter.inputPixelPitchY = placement.destinationRect.height / placement.nativeSize.height
                output = filter.outputImage ?? screen
                filter.inputImage = nil
            }
            frame = output.composited(over: frame)
        }
        return frame.cropped(to: canvas)
    }

    /// Renders `compose` from `source` into `target` on `commandBuffer`.
    /// - Returns: `false` when nothing was encoded (the texture cannot be read by Core Image).
    @discardableResult
    public func render(source: MTLTexture, placements: [LCDScreenPlacement], into target: MTLTexture,
                       context: CIContext, commandBuffer: MTLCommandBuffer,
                       screenFilters: [ScreenImageFilter?] = []) -> Bool {
        guard let image = FrameImageFilter.image(of: source) else { return false }
        let canvas = CGRect(x: 0, y: 0, width: target.width, height: target.height)
        return FrameImageFilter.render(compose(source: image, placements: placements, canvas: canvas,
                                               screenFilters: screenFilters),
                                       into: target, context: context, commandBuffer: commandBuffer)
    }

    /// The screen's source region, turned upright, run through `filter`, and scaled into
    /// its destination. The region is clamped before scaling so linear sampling at its
    /// edges never reaches the other screen.
    func place(source: CIImage, _ placement: LCDScreenPlacement, filter: ScreenImageFilter? = nil) -> CIImage? {
        let from = placement.sourceRect, into = placement.destinationRect
        guard from.width > 0, from.height > 0, into.width > 0, into.height > 0,
              placement.nativeSize.width > 0, placement.nativeSize.height > 0 else { return nil }
        // Upright at the origin: the texture's y grows downwards unless the region is
        // stored bottom row first.
        let toUpright = placement.sourceIsFlipped
            ? CGAffineTransform(translationX: -from.minX, y: -from.minY)
            : CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: -from.minX, ty: from.maxY)
        let screenRect = CGRect(origin: .zero, size: from.size)
        var screen = source.cropped(to: from).clampedToExtent().transformed(by: toUpright).cropped(to: screenRect)
        if let filter {
            screen = FrameImageFilter.opaque(filter(screen) ?? screen, in: screenRect)
        }
        // Into the destination, back to the target's downward y.
        let scaleX = into.width / from.width, scaleY = into.height / from.height
        let toDestination = CGAffineTransform(a: scaleX, b: 0, c: 0, d: -scaleY, tx: into.minX, ty: into.maxY)
        return screen.clampedToExtent().transformed(by: toDestination).cropped(to: into)
    }
}

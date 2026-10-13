//
//  LCDScreenComposer.swift
//  PVShaders
//
//  Draws the screens of a dual-screen layout (DS skins) into one frame with
//  `LCDScreenFilter` applied per screen, at output resolution so the grid
//  falls on each screen's emulated pixels.
//
//  Coordinates are texture rows: Core Image reads row r of a Metal texture as
//  y = r and writes y = r back to row r, so y grows downwards here, as in the
//  drawable.
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

/// Composes dual-screen frames with the LCD look. Keeps one filter per screen across
/// frames, so use one instance from one thread.
public final class LCDScreenComposer {
    private var filters: [LCDScreenFilter] = []

    public init() {}

    /// A context that passes colours through untouched, so the screens match the plain
    /// blit apart from the filter itself.
    public static func makeContext(device: MTLDevice) -> CIContext {
        CIContext(mtlDevice: device, options: [
            .workingColorSpace: NSNull(),
            .outputColorSpace: NSNull(),
            .cacheIntermediates: false
        ])
    }

    /// The whole frame: black, with every placed screen drawn over it.
    public func compose(source: CIImage, placements: [LCDScreenPlacement], canvas: CGRect) -> CIImage {
        while filters.count < placements.count { filters.append(LCDScreenFilter()) }
        var frame = CIImage(color: .black).cropped(to: canvas)
        for (placement, filter) in zip(placements, filters) {
            guard let screen = place(source: source, placement) else { continue }
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
                       context: CIContext, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let image = CIImage(mtlTexture: source, options: [.colorSpace: NSNull()]) else { return false }
        let canvas = CGRect(x: 0, y: 0, width: target.width, height: target.height)
        let destination = CIRenderDestination(mtlTexture: target, commandBuffer: commandBuffer)
        destination.colorSpace = nil
        do {
            try context.startTask(toRender: compose(source: image, placements: placements, canvas: canvas),
                                  to: destination)
            return true
        } catch {
            return false
        }
    }

    /// The screen's source region scaled into its destination. The region is clamped
    /// before scaling so linear sampling at its edges never reaches the other screen.
    func place(source: CIImage, _ placement: LCDScreenPlacement) -> CIImage? {
        let from = placement.sourceRect, into = placement.destinationRect
        guard from.width > 0, from.height > 0, into.width > 0, into.height > 0,
              placement.nativeSize.width > 0, placement.nativeSize.height > 0 else { return nil }
        let scaleX = into.width / from.width, scaleY = into.height / from.height
        let offsetX = into.minX - from.minX * scaleX
        let transform = placement.sourceIsFlipped
            ? CGAffineTransform(a: scaleX, b: 0, c: 0, d: -scaleY, tx: offsetX, ty: into.maxY + from.minY * scaleY)
            : CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleY, tx: offsetX, ty: into.minY - from.minY * scaleY)
        return source.cropped(to: from).clampedToExtent().transformed(by: transform).cropped(to: into)
    }
}

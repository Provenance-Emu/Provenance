// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation

/// Top Shelf frame selected from the artwork itself, including custom and regional covers.
public enum LibraryArtworkShape: String, Sendable, CaseIterable {
    case poster, square, wide

    /// Pixel bounds for the 2x Top Shelf image. The renderer may use a smaller
    /// proportional canvas to avoid enlarging a low-resolution source.
    public var pixelSize: CGSize {
        switch self {
        case .poster: return CGSize(width: 808, height: 1216)
        case .square: return CGSize(width: 1216, height: 1216)
        case .wide: return CGSize(width: 1816, height: 1024)
        }
    }

    /// Picks the frame with the nearest aspect ratio on a logarithmic scale,
    /// minimizing padding without confusing a console's screen with its box art.
    public static func shape(for size: CGSize) -> LibraryArtworkShape {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return .square }
        let ratio = size.width / size.height
        return allCases.min {
            abs(log(ratio / ($0.pixelSize.width / $0.pixelSize.height)))
                < abs(log(ratio / ($1.pixelSize.width / $1.pixelSize.height)))
        } ?? .square
    }

    /// Aspect-fit canvas and draw rect. Never crops or stretches the source,
    /// and never resamples it upward just to inflate the cache's pixel count.
    public func layout(for source: CGSize) -> (canvas: CGSize, drawing: CGRect)? {
        guard source.width.isFinite, source.height.isFinite, source.width > 0, source.height > 0 else { return nil }
        let bounds = pixelSize
        let canvasScale = min(1, max(source.width / bounds.width, source.height / bounds.height))
        let canvas = CGSize(width: max(1, (bounds.width * canvasScale).rounded()),
                            height: max(1, (bounds.height * canvasScale).rounded()))
        let scale = min(1, min(canvas.width / source.width, canvas.height / source.height))
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        let origin = CGPoint(x: (canvas.width - size.width) * 0.5, y: (canvas.height - size.height) * 0.5)
        let drawing = CGRect(origin: origin, size: size)
        return (canvas, drawing)
    }
}

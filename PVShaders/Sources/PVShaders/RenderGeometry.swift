//
//  RenderGeometry.swift
//  PVShaders
//
//  Where the emulated picture goes inside a drawable.
//

import CoreGraphics

public enum RenderGeometry {
    /// Largest rect with `aspect`'s proportions that fits in `bounds`, centred.
    /// Returns `bounds` unchanged when either size is empty.
    public static func aspectFit(aspect: CGSize, in bounds: CGRect) -> CGRect {
        guard aspect.width > 0, aspect.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / aspect.width, bounds.height / aspect.height)
        let size = CGSize(width: aspect.width * scale, height: aspect.height * scale)
        return CGRect(x: bounds.midX - size.width / 2,
                      y: bounds.midY - size.height / 2,
                      width: size.width,
                      height: size.height)
    }

    /// The picture's rect in drawable pixels.
    ///
    /// The view's frame normally already has the picture's proportions, so the
    /// result is the whole drawable. While the frame is still a placeholder
    /// (for example full screen before a skin reports its screen rect) the
    /// picture is letterboxed inside it instead of covering the whole view.
    ///
    /// The drawable is stretched over the view's bounds, so the fit is computed
    /// in view space and then mapped to drawable pixels.
    ///
    /// - Parameters:
    ///   - aspect: the picture's display aspect (core `aspectSize`).
    ///   - viewSize: the view's bounds size, in points.
    ///   - drawableSize: the drawable size, in pixels.
    public static func contentRect(aspect: CGSize, viewSize: CGSize, drawableSize: CGSize) -> CGRect {
        let full = CGRect(origin: .zero, size: drawableSize)
        guard viewSize.width > 0, viewSize.height > 0, drawableSize.width > 0, drawableSize.height > 0 else {
            return full
        }
        let fit = aspectFit(aspect: aspect, in: CGRect(origin: .zero, size: viewSize))
        // Within a point of the bounds: the view is already sized to the picture.
        if viewSize.width - fit.width < 1, viewSize.height - fit.height < 1 {
            return full
        }
        let sx = drawableSize.width / viewSize.width
        let sy = drawableSize.height / viewSize.height
        return CGRect(x: fit.minX * sx, y: fit.minY * sy, width: fit.width * sx, height: fit.height * sy).integral
            .intersection(full)
    }
}

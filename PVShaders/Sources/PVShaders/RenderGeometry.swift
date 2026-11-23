//
//  RenderGeometry.swift
//  PVShaders
//
//  Where the emulated picture goes inside a drawable.
//

import CoreGraphics

/// How a scene is placed on a display that does not have its proportions.
public struct SceneFraming: Equatable, Sendable {
    /// The scene covers the whole display and loses its edges, rather than fitting inside it
    /// with bars.
    public var coversDisplay: Bool
    /// Enlarges the scene about the display's centre. Values under 1 count as 1.
    public var zoom: CGFloat
    /// The centred part of the scene that never leaves the display, as a fraction of the
    /// scene's width and height. Zero keeps nothing in particular.
    public var kept: CGSize

    public init(coversDisplay: Bool, zoom: CGFloat = 1, kept: CGSize = .zero) {
        self.coversDisplay = coversDisplay
        self.zoom = zoom
        self.kept = kept
    }

    /// All of the scene, with bars where the display has another shape.
    public static let whole = SceneFraming(coversDisplay: false)
}

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

    /// A scene of `aspect` fitted into a drawable, in whole pixels: all of it when the display
    /// has the scene's proportions, letterboxed or pillarboxed otherwise.
    public static func sceneRect(aspect: CGSize, drawableSize: CGSize) -> CGRect {
        let full = CGRect(origin: .zero, size: drawableSize)
        return aspectFit(aspect: aspect, in: full).integral.intersection(full)
    }

    /// A scene of `aspect` placed on a drawable by `framing`, in whole pixels and centred. The
    /// rect is larger than the drawable where the scene is cropped, so it is a viewport, not a
    /// region of the drawable.
    public static func sceneRect(aspect: CGSize, drawableSize: CGSize, framing: SceneFraming) -> CGRect {
        let fitted = sceneRect(aspect: aspect, drawableSize: drawableSize)
        guard framing != .whole, aspect.width > 0, aspect.height > 0, !fitted.isEmpty else { return fitted }
        let fit = min(drawableSize.width / aspect.width, drawableSize.height / aspect.height)
        let cover = max(drawableSize.width / aspect.width, drawableSize.height / aspect.height)
        var scale = (framing.coversDisplay ? cover : fit) * max(framing.zoom, 1)
        if framing.kept.width > 0 { scale = min(scale, drawableSize.width / (framing.kept.width * aspect.width)) }
        if framing.kept.height > 0 { scale = min(scale, drawableSize.height / (framing.kept.height * aspect.height)) }
        // Within a hundredth of a pixel of the fitted scene: use it, bars and all.
        guard scale * aspect.width - fitted.width > 0.01 || scale * aspect.height - fitted.height > 0.01 else { return fitted }
        let size = CGSize(width: (aspect.width * scale).rounded(), height: (aspect.height * scale).rounded())
        return CGRect(x: ((drawableSize.width - size.width) / 2).rounded(.down),
                      y: ((drawableSize.height - size.height) / 2).rounded(.down),
                      width: size.width, height: size.height)
    }

    /// The pixel size of a part of a scene (`part`, in the units of `canvas`) once the scene
    /// is drawn `sceneSize` pixels large. At least one pixel each way.
    public static func pixelSize(of part: CGSize, canvas: CGSize, sceneSize: CGSize) -> (width: Int, height: Int) {
        guard canvas.width > 0, canvas.height > 0 else { return (1, 1) }
        let width = part.width / canvas.width * sceneSize.width
        let height = part.height / canvas.height * sceneSize.height
        return (max(1, Int(width.rounded())), max(1, Int(height.rounded())))
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

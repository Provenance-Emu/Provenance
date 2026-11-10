//
//  SkinViewportGeometry.swift
//  PVUIBase
//
//  Where a packaged skin's image and its game screen land on screen, computed the way
//  SkinKit's renderer (`DeltaSkinView.calculateLayout`) computes it.
//
//  PVEmulatorViewController uses this for the frame it applies before the renderer has
//  broadcast its own. Both must agree: when they differ, whichever ran last decided where
//  the game picture sat, and the picture ended up off the skin's screen area.
//

import CoreGraphics

enum SkinViewportGeometry {
    /// Insets the skin renderer lays out against.
    ///
    /// The renderer reads `GeometryProxy.safeAreaInsets`, and `EmulatorWrapperView` hosts it under
    /// `.ignoresSafeArea(.all)`, so it sees none: a skin is drawn against the whole screen, notch
    /// and home indicator included. Using the view controller's own `view.safeAreaInsets` here
    /// scaled the skin into the safe area instead (0.87 instead of 0.97 on an iPhone 17 in
    /// portrait) and put the game picture ~50 pt lower and 10% smaller than the skin's screen.
    static let rendererInsets = Insets.zero

    struct Insets: Equatable {
        var top: CGFloat
        var left: CGFloat
        var bottom: CGFloat
        var right: CGFloat

        static let zero = Insets(top: 0, left: 0, bottom: 0, right: 0)
    }

    /// The rect the skin image is drawn in: `mappingSize` scaled to fit `containerSize` inside
    /// `insets`, centred horizontally, and either resting on the bottom inset (iPhone portrait)
    /// or centred vertically (everything else).
    ///
    /// - Returns: `nil` when either size has no area.
    static func skinImageFrame(containerSize: CGSize, mappingSize: CGSize, insets: Insets = rendererInsets,
                               restsOnBottomEdge: Bool) -> CGRect? {
        guard containerSize.width > 0, containerSize.height > 0,
              mappingSize.width > 0, mappingSize.height > 0 else { return nil }
        let availableWidth = max(0, containerSize.width - insets.left - insets.right)
        let availableHeight = max(0, containerSize.height - insets.top - insets.bottom)
        let scale = min(availableWidth / mappingSize.width, availableHeight / mappingSize.height)
        let size = CGSize(width: mappingSize.width * scale, height: mappingSize.height * scale)
        let x = insets.left + (availableWidth - size.width) / 2
        let y = restsOnBottomEdge
            ? containerSize.height - size.height - insets.bottom
            : insets.top + (availableHeight - size.height) / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// A screen rect given in the skin's own coordinates, placed inside `skinImageFrame`.
    ///
    /// - Parameter screen: in `mappingSize` units, or already normalised to 0...1 (no component
    ///   above 1), the two forms skins use.
    static func screenFrame(_ screen: CGRect, mappingSize: CGSize, in skinImageFrame: CGRect) -> CGRect {
        let unit = normalized(screen, mappingSize: mappingSize)
        return CGRect(x: skinImageFrame.minX + unit.minX * skinImageFrame.width,
                      y: skinImageFrame.minY + unit.minY * skinImageFrame.height,
                      width: unit.width * skinImageFrame.width,
                      height: unit.height * skinImageFrame.height)
    }

    /// `frame` in 0...1 coordinates. A frame with no component above 1 is taken as normalised
    /// already; small or negative values alone do not trigger the division.
    static func normalized(_ frame: CGRect, mappingSize: CGSize) -> CGRect {
        guard frame.origin.x > 1 || frame.origin.y > 1 || frame.width > 1 || frame.height > 1,
              mappingSize.width > 0, mappingSize.height > 0 else { return frame }
        return CGRect(x: frame.minX / mappingSize.width, y: frame.minY / mappingSize.height,
                      width: frame.width / mappingSize.width, height: frame.height / mappingSize.height)
    }
}

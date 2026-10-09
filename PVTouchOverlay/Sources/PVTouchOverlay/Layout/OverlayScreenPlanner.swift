import Foundation
import CoreGraphics

public enum OverlayScreenPlanner {
    /// Gap between the picture and the nearest control group.
    public static let gap: CGFloat = 8
    /// Each DS screen is 256x192.
    public static let dsAspect: CGFloat = 4.0 / 3.0
    /// 3DS: 400x240 top over 320x240 bottom.
    public static let n3dsTopAspect: CGFloat = 400.0 / 240.0
    public static let n3dsBottomAspect: CGFloat = 320.0 / 240.0

    public static func screenFrames(policy: OverlayScreenPolicy, canvas: OverlayCanvas,
                                    groups: [ResolvedGroup], gameAspect: CGFloat) -> [CGRect] {
        let safe = canvas.safeRect
        let aspect = gameAspect > 0 ? gameAspect : 4.0 / 3.0
        switch policy {
        case .fill:
            return [safe]
        case .topBand:
            let band = topBand(safe: safe, groups: groups)
            return [aspectFit(aspect, in: band)]
        case .centerColumn:
            let column = centerColumn(safe: safe, groups: groups)
            return [aspectFit(aspect, in: column)]
        case .dualStacked:
            let band = topBand(safe: safe, groups: groups)
            let half = CGRect(x: band.minX, y: band.minY, width: band.width, height: max(0, (band.height - gap) / 2))
            let size = aspectFit(dsAspect, in: half).size
            // Centre the pair in the band so the slack above equals the slack below.
            let slack = max(0, (band.height - (size.height * 2 + gap)) / 2)
            let top = CGRect(x: band.midX - size.width / 2, y: band.minY + slack,
                             width: size.width, height: size.height)
            return [top, top.offsetBy(dx: 0, dy: size.height + gap)]
        case .dualStacked3DS:
            // Both screens share the band's width budget; the 5:3 top screen is the wider one, so it
            // sets the width and the 4:3 bottom screen is centred under it at the same height.
            let band = topBand(safe: safe, groups: groups)
            let half = CGRect(x: band.minX, y: band.minY, width: band.width, height: max(0, (band.height - gap) / 2))
            let topSize = aspectFit(n3dsTopAspect, in: half).size
            let bottomWidth = topSize.height * n3dsBottomAspect
            let slack = max(0, (band.height - (topSize.height * 2 + gap)) / 2)
            let top = CGRect(x: band.midX - topSize.width / 2, y: band.minY + slack,
                             width: topSize.width, height: topSize.height)
            let bottom = CGRect(x: band.midX - bottomWidth / 2, y: top.maxY + gap,
                                width: bottomWidth, height: topSize.height)
            return [top, bottom]
        }
    }

    /// The band above the controls. Every non-touch-surface group anchored to the bottom edge (leading,
    /// trailing or centre) reserves space, wherever it resolved; groups with top or centre anchors, touch
    /// surfaces and toggled groups (a keypad) float over the picture. With no reserving group the band is
    /// the whole safe rect.
    static func topBand(safe: CGRect, groups: [ResolvedGroup]) -> CGRect {
        let highest = groups.filter { !isTouchSurfaceGroup($0) && !isToggled($0) && isBottomAnchored($0) }
            .map(\.frame.minY).min() ?? safe.maxY
        let bottom = max(safe.minY, min(safe.maxY, highest - gap))
        return CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: bottom - safe.minY)
    }

    static func isBottomAnchored(_ group: ResolvedGroup) -> Bool {
        switch group.group.placement.anchor {
        case .bottomLeading, .bottomTrailing, .bottomCenter: return true
        default: return false
        }
    }

    /// A group that exists only while an action's toggle is on; it overlays the picture and never moves it.
    static func isToggled(_ group: ResolvedGroup) -> Bool {
        group.group.toggledBy != nil
    }

    static func isTouchSurfaceGroup(_ group: ResolvedGroup) -> Bool {
        group.group.controls.contains { isTouchSurface($0.kind) }
    }

    static func isTouchSurface(_ kind: OverlayControlKind) -> Bool {
        if case .touchSurface = kind { return true }
        return false
    }

    /// The column between the side clusters. Touch-surface and toggled groups are ignored. A group spanning the safe
    /// rect's centre line lowers the column's bottom edge; only the remaining groups set the side edges.
    static func centerColumn(safe: CGRect, groups: [ResolvedGroup]) -> CGRect {
        let mid = safe.midX
        let candidates = groups.filter { !isTouchSurfaceGroup($0) && !isToggled($0) }
        let centred = candidates.filter { $0.frame.minX < mid && mid < $0.frame.maxX }
        let sides = candidates.filter { !($0.frame.minX < mid && mid < $0.frame.maxX) }
        let leftEdge = sides.filter { $0.frame.midX < mid }.map { $0.frame.maxX + gap }.max() ?? safe.minX
        let rightEdge = sides.filter { $0.frame.midX >= mid }.map { $0.frame.minX - gap }.min() ?? safe.maxX
        let minX = min(max(safe.minX, leftEdge), safe.maxX)
        let maxX = max(minX, min(safe.maxX, rightEdge))
        let bottom = max(safe.minY, min(safe.maxY, (centred.map(\.frame.minY).min() ?? safe.maxY + gap) - gap))
        return CGRect(x: minX, y: safe.minY, width: maxX - minX, height: bottom - safe.minY)
    }

    static func aspectFit(_ aspect: CGFloat, in rect: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return CGRect(origin: rect.origin, size: .zero) }
        var width = rect.width
        var height = width / aspect
        if height > rect.height { height = rect.height; width = height * aspect }
        return CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    }
}

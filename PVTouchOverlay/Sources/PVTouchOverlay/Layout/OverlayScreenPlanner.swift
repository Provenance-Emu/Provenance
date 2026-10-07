import Foundation
import CoreGraphics

public enum OverlayScreenPlanner {
    /// Gap between the picture and the nearest control group.
    public static let gap: CGFloat = 8
    /// Each DS screen is 256x192.
    public static let dsAspect: CGFloat = 4.0 / 3.0

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
            let half = CGRect(x: band.minX, y: band.minY, width: band.width, height: (band.height - gap) / 2)
            let top = aspectFit(dsAspect, in: half)
            let bottom = top.offsetBy(dx: 0, dy: top.height + gap)
            // Centre the pair vertically in the band.
            let pairHeight = bottom.maxY - top.minY
            let shift = (band.height - pairHeight) / 2
            return [top.offsetBy(dx: 0, dy: shift), bottom.offsetBy(dx: 0, dy: shift)]
        }
    }

    static func topBand(safe: CGRect, groups: [ResolvedGroup]) -> CGRect {
        let highest = groups.filter { !$0.group.controls.contains { isTouchSurface($0.kind) } }
            .map(\.frame.minY).min() ?? safe.maxY
        let bottom = max(safe.minY, min(safe.maxY, highest - gap))
        return CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: bottom - safe.minY)
    }

    static func isTouchSurface(_ kind: OverlayControlKind) -> Bool {
        if case .touchSurface = kind { return true }
        return false
    }

    static func centerColumn(safe: CGRect, groups: [ResolvedGroup]) -> CGRect {
        let mid = safe.midX
        let leftEdge = groups.filter { $0.frame.midX < mid }.map(\.frame.maxX).max() ?? safe.minX
        let rightEdge = groups.filter { $0.frame.midX >= mid }.map(\.frame.minX).min() ?? safe.maxX
        let minX = min(max(safe.minX, leftEdge + gap), safe.maxX)
        let maxX = max(minX, min(safe.maxX, rightEdge - gap))
        return CGRect(x: minX, y: safe.minY, width: maxX - minX, height: safe.height)
    }

    static func aspectFit(_ aspect: CGFloat, in rect: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return CGRect(origin: rect.origin, size: .zero) }
        var width = rect.width
        var height = width / aspect
        if height > rect.height { height = rect.height; width = height * aspect }
        return CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    }
}

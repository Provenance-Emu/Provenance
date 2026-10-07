import Foundation
import CoreGraphics

public enum OverlayLayoutEngine {
    /// Reference phone width the templates are authored against.
    public static let referenceWidth: CGFloat = 390
    public static let maxReferenceScale: CGFloat = 1.35
    /// Default outset applied to every control's hit frame (points at scale 1).
    public static let extendedEdges: CGFloat = 20
    public static let scaleRange: ClosedRange<CGFloat> = 0.5...2.0

    public static func referenceScale(for canvas: OverlayCanvas) -> CGFloat {
        min(max(min(canvas.size.width, canvas.size.height) / referenceWidth, 1), maxReferenceScale)
    }

    public static func resolve(template: OverlayTemplate,
                               canvas: OverlayCanvas,
                               overrides: OverlayLayoutOverrides,
                               gameAspect: CGFloat) -> OverlayLayout {
        let unit = referenceScale(for: canvas)
        let groups = template.groups.map { group -> ResolvedGroup in
            let override = overrides.groups[group.id] ?? .empty
            let scale = clampedScale(override.scale ?? CGSize(width: group.scale, height: group.scale))
            let natural = group.naturalSize
            let size = CGSize(width: natural.width * unit * scale.width, height: natural.height * unit * scale.height)

            var center = override.center?.resolve(in: canvas)
                ?? placementCenter(group.placement, size: size, canvas: canvas)
            center = clampCenter(center, size: size, within: canvas.safeRect)
            let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)

            let controls = group.controls.map { control -> ResolvedControl in
                let ctl = override.buttons[control.id] ?? ControlOverride()
                let width = control.frame.width * unit * scale.width * ctl.scale
                let height = control.frame.height * unit * scale.height * ctl.scale
                let midX = origin.x + (control.frame.midX * unit * scale.width) + ctl.offset.x
                let midY = origin.y + (control.frame.midY * unit * scale.height) + ctl.offset.y
                let frame = CGRect(x: midX - width / 2, y: midY - height / 2, width: width, height: height)
                return ResolvedControl(control: control, frame: frame,
                                       hitFrame: frame.insetBy(dx: -extendedEdges * unit, dy: -extendedEdges * unit))
            }
            return ResolvedGroup(group: group, frame: CGRect(origin: origin, size: size), controls: controls,
                                 scale: scale, opacity: group.opacity * (override.opacity ?? 1))
        }
        let screens = OverlayScreenPlanner.screenFrames(policy: template.screenPolicy, canvas: canvas,
                                                        groups: groups, gameAspect: gameAspect)
        return OverlayLayout(padKind: template.padKind, orientation: template.orientation,
                             groups: groups, screenFrames: screens)
    }

    static func clampedScale(_ scale: CGSize) -> CGSize {
        CGSize(width: min(max(scale.width, scaleRange.lowerBound), scaleRange.upperBound),
               height: min(max(scale.height, scaleRange.lowerBound), scaleRange.upperBound))
    }

    static func placementCenter(_ placement: OverlayPlacement, size: CGSize, canvas: OverlayCanvas) -> CGPoint {
        let rect = canvas.safeRect
        let posX: CGFloat
        let posY: CGFloat
        switch placement.anchor {
        case .bottomLeading, .topLeading, .centerLeading: posX = rect.minX + placement.inset.x + size.width / 2
        case .bottomTrailing, .topTrailing, .centerTrailing: posX = rect.maxX - placement.inset.x - size.width / 2
        case .bottomCenter, .topCenter, .center, .fill, .fillInset: posX = rect.midX
        }
        switch placement.anchor {
        case .bottomLeading, .bottomTrailing, .bottomCenter: posY = rect.maxY - placement.inset.y - size.height / 2
        case .topLeading, .topTrailing, .topCenter: posY = rect.minY + placement.inset.y + size.height / 2
        case .centerLeading, .centerTrailing, .center, .fill, .fillInset: posY = rect.midY
        }
        return CGPoint(x: posX, y: posY)
    }

    static func clampCenter(_ center: CGPoint, size: CGSize, within rect: CGRect) -> CGPoint {
        // When the group is larger than the safe rect, centre it rather than pinning a corner.
        let posX = size.width >= rect.width
            ? rect.midX : min(max(center.x, rect.minX + size.width / 2), rect.maxX - size.width / 2)
        let posY = size.height >= rect.height
            ? rect.midY : min(max(center.y, rect.minY + size.height / 2), rect.maxY - size.height / 2)
        return CGPoint(x: posX, y: posY)
    }
}

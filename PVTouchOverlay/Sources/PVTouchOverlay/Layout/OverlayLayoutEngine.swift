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
                               gameAspect: CGFloat,
                               shownToggles: Set<OverlayAction> = [],
                               reservesControlSpace: Bool = true,
                               arrangesConsoleRow: Bool = false) -> OverlayLayout {
        let unit = referenceScale(for: canvas)
        // A toggled group that is off takes no part in the layout, so the screen planner never reserves room for it.
        let present = template.groups.filter { $0.toggledBy.map(shownToggles.contains) ?? true }
        let consoleRow = arrangesConsoleRow ? consolePlacements(groups: present, overrides: overrides, canvas: canvas, unit: unit) : [:]
        let resolved = present.map { group -> ResolvedGroup in
            let override = overrides.groups[group.id] ?? .empty
            let scale = clampedScale(override.scale ?? CGSize(width: group.scale, height: group.scale))
            let natural = group.naturalSize
            let size = CGSize(width: natural.width * unit * scale.width, height: natural.height * unit * scale.height)

            var center = override.center?.resolve(in: canvas)
                ?? placementCenter(consoleRow[group.id] ?? group.placement, size: size, canvas: canvas, unit: unit)
            center = clampCenter(center, size: size, within: canvas.safeRect)
            let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)

            let controls = group.controls.map { control -> ResolvedControl in
                let ctl = override.buttons[control.id] ?? ControlOverride()
                let width = control.frame.width * unit * scale.width * clampedControlScale(ctl.scale)
                let height = control.frame.height * unit * scale.height * clampedControlScale(ctl.scale)
                let midX = origin.x + (control.frame.midX * unit * scale.width) + ctl.offset.x
                let midY = origin.y + (control.frame.midY * unit * scale.height) + ctl.offset.y
                let frame = CGRect(x: midX - width / 2, y: midY - height / 2, width: width, height: height)
                return ResolvedControl(control: control, frame: frame,
                                       hitFrame: frame.insetBy(dx: -extendedEdges * unit, dy: -extendedEdges * unit))
            }
            return ResolvedGroup(group: group, frame: CGRect(origin: origin, size: size), controls: controls,
                                 scale: scale, opacity: group.opacity * clampedOpacity(override.opacity ?? 1))
        }
        let screens = OverlayScreenPlanner.screenFrames(policy: template.screenPolicy, canvas: canvas,
                                                        groups: resolved, gameAspect: gameAspect,
                                                        reservesControlSpace: reservesControlSpace)
        let groups = resolved.map { snapSurface($0, to: screens) }
        return OverlayLayout(padKind: template.padKind, orientation: template.orientation,
                             groups: groups, screenFrames: screens)
    }

    /// Fit both console rows side by side when their default centres are still in use.
    /// Keep the group IDs and local frames so existing layout edits still apply.
    private static func consolePlacements(groups: [OverlayGroup], overrides: OverlayLayoutOverrides,
                                          canvas: OverlayCanvas, unit: CGFloat) -> [String: OverlayPlacement] {
        guard canvas.orientation == .landscape,
              let switches = groups.first(where: { $0.id == "switches" }),
              let buttons = groups.first(where: { $0.id == "system" }),
              overrides.groups[switches.id]?.center == nil, overrides.groups[buttons.id]?.center == nil else { return [:] }
        func width(_ group: OverlayGroup) -> CGFloat {
            let scale = overrides.groups[group.id]?.scale?.width ?? group.scale
            return group.naturalSize.width * min(max(scale, scaleRange.lowerBound), scaleRange.upperBound)
        }
        let switchWidth = width(switches)
        let buttonWidth = width(buttons)
        let gap = 2 * extendedEdges
        let rowWidth = switchWidth + gap + buttonWidth
        let safeWidth = canvas.safeRect.width / unit
        guard rowWidth <= safeWidth else { return [:] }
        let left = (safeWidth - rowWidth) / 2
        let bottom = buttons.placement.inset.y
        return [
            switches.id: OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: left, y: bottom)),
            buttons.id: OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: left + switchWidth + gap, y: bottom)),
        ]
    }

    /// A group holding a single touch surface fills the screen it drives: the bottom screen for the DS
    /// stylus, the first (only) picture for everything else. Left as resolved when there are no screens.
    static func snapSurface(_ group: ResolvedGroup, to screenFrames: [CGRect]) -> ResolvedGroup {
        guard group.controls.count == 1, let resolved = group.controls.first,
              case .touchSurface(let role) = resolved.control.kind,
              let target = role == .dsScreen ? screenFrames.last : screenFrames.first else { return group }
        let control = ResolvedControl(control: resolved.control, frame: target, hitFrame: target)
        return ResolvedGroup(group: group.group, frame: target, controls: [control],
                             scale: group.scale, opacity: group.opacity)
    }

    static let opacityRange: ClosedRange<CGFloat> = 0.1...1

    static func clampedControlScale(_ value: CGFloat) -> CGFloat {
        min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
    }

    static func clampedOpacity(_ value: CGFloat) -> CGFloat {
        min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }

    public static func clampedScale(_ scale: CGSize) -> CGSize {
        CGSize(width: min(max(scale.width, scaleRange.lowerBound), scaleRange.upperBound),
               height: min(max(scale.height, scaleRange.lowerBound), scaleRange.upperBound))
    }

    /// `placement.inset` is authored at reference scale, so it is multiplied by `unit` here.
    static func placementCenter(_ placement: OverlayPlacement, size: CGSize, canvas: OverlayCanvas,
                                unit: CGFloat) -> CGPoint {
        let rect = canvas.safeRect
        let inset = CGPoint(x: placement.inset.x * unit, y: placement.inset.y * unit)
        let posX: CGFloat
        let posY: CGFloat
        switch placement.anchor {
        case .bottomLeading, .topLeading, .centerLeading: posX = rect.minX + inset.x + size.width / 2
        case .bottomTrailing, .topTrailing, .centerTrailing: posX = rect.maxX - inset.x - size.width / 2
        case .bottomCenter, .topCenter, .center, .fill, .fillInset: posX = rect.midX
        }
        switch placement.anchor {
        case .bottomLeading, .bottomTrailing, .bottomCenter: posY = rect.maxY - inset.y - size.height / 2
        case .topLeading, .topTrailing, .topCenter: posY = rect.minY + inset.y + size.height / 2
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

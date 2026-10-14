import Foundation
import CoreGraphics

/// Multi-button ("fat finger") hit-testing for programmatic overlay buttons, ported from iFly's arcade
/// cluster and scaled to each button's size.
///
/// The finger's contact circle, not just its centre, is tested against each button: a finger between two
/// buttons presses both, and a drag mashes across a run of them. The nearest button gets the full reach;
/// any other needs the touch 10% deeper, so a press riding one button's edge, or a held finger wobbling,
/// does not graze a neighbour.
///
/// iFly works in fixed points (34pt buttons, contact clamped to 20...50pt, 92pt pitch). Provenance buttons
/// are smaller and resized by the layout, so the contact clamp is the same fraction of the button radius
/// iFly uses (20/34 to 50/34), which keeps a press on a button's centre from reaching its neighbour.
public enum OverlayMultiButtonTouch {
    /// iFly's contact clamp as fractions of its 34pt button radius.
    public static let minContactFraction: CGFloat = 20.0 / 34.0
    public static let maxContactFraction: CGFloat = 50.0 / 34.0
    /// Reach factor for every button but the nearest.
    public static let overflowFactor: CGFloat = 0.9

    /// Whether a group's buttons use multi-button touch. As in iFly, only an arcade panel's buttons do
    /// (with the user's arcade setting on); console face buttons always press one button per finger.
    public static func applies(toGroup groupID: String, familyID: String, arcadeEnabled: Bool) -> Bool {
        arcadeEnabled && familyID == ArcadeStickFamily.id && groupID == ArcadeStickFamily.faceGroupID
    }

    /// Radius of a control's round part: half its shorter side.
    public static func radius(of frame: CGRect) -> CGFloat { min(frame.width, frame.height) / 2 }

    /// Distance from `point` to the control's shape, approximated as a rounded rectangle whose corner
    /// radius is `radius(of:)`: the centre distance for a round button, the distance to the centre line
    /// for a pill or bar. Measured from the shape's core, so a point on a round button's rim is `radius`.
    public static func coreDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let core = frame.insetBy(dx: radius(of: frame), dy: radius(of: frame))
        let nearestX = min(max(point.x, core.minX), core.maxX)
        let nearestY = min(max(point.y, core.minY), core.maxY)
        return hypot(point.x - nearestX, point.y - nearestY)
    }

    /// The contact radius used for a button: the finger's reported radius clamped to the button's size.
    public static func contactRadius(_ touchRadius: CGFloat, buttonRadius: CGFloat) -> CGFloat {
        min(max(touchRadius, buttonRadius * minContactFraction), buttonRadius * maxContactFraction)
    }

    /// Ids of the controls a touch covers. `controls` must already be limited to multi-press eligible
    /// gameplay buttons.
    public static func hits(at point: CGPoint, touchRadius: CGFloat, controls: [ResolvedControl]) -> Set<String> {
        let measured = controls.map { (id: $0.id, frame: $0.frame, distance: coreDistance(from: point, to: $0.frame)) }
        guard let nearest = measured.min(by: { $0.distance < $1.distance }) else { return [] }
        var hit = Set<String>()
        for entry in measured {
            let buttonRadius = radius(of: entry.frame)
            let reach = buttonRadius + contactRadius(touchRadius, buttonRadius: buttonRadius)
            let limit = entry.id == nearest.id ? reach : reach * overflowFactor
            if entry.distance <= limit { hit.insert(entry.id) }
        }
        return hit
    }
}

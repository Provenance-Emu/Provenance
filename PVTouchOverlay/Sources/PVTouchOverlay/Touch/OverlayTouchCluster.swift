#if canImport(UIKit)
import UIKit

/// One multi-touch surface over a group of buttons and d-pads. Each event recomputes the union of hits
/// across all live touches and emits only when the set changes. `OverlayTouchTracker` holds the rules:
/// drag across gameplay controls, optional multi-button touch, and the system-control lockout.
public final class OverlayTouchCluster: UIView {
    public var controls: [ResolvedControl] = [] {
        didSet {
            tracker.controls = controls
            if !tracker.isEmpty { recompute() }
        }
    }
    /// Multi-button ("fat finger") touch for this cluster's gameplay buttons.
    public var multiButton = false {
        didSet {
            tracker.multiButton = multiButton
            if oldValue != multiButton, !tracker.isEmpty { recompute() }
        }
    }
    /// Controls are in canvas points and the view may be offset. Set by the host.
    public var canvasOrigin: CGPoint = .zero
    public var onChange: ((Set<OverlayHit>) -> Void)?

    /// Live touches, kept off SwiftUI state for performance.
    private var tracker = OverlayTouchTracker<ObjectIdentifier>()
    /// Touches dropped by `releaseAll()`; their later events are ignored until a new touch begins.
    private var released = Set<ObjectIdentifier>()
    private var current = Set<OverlayHit>()

    public override init(frame: CGRect) {
        super.init(frame: frame)
#if !os(tvOS)
        isMultipleTouchEnabled = true
#endif
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        OverlayHitTester.topControl(at: canvasPoint(point), in: controls) != nil
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            released.remove(key)
            tracker.began(key, at: canvasPoint(touch.location(in: self)), radius: Self.contactRadius(of: touch))
        }
        recompute()
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where !released.contains(ObjectIdentifier(touch)) {
            tracker.moved(ObjectIdentifier(touch), to: canvasPoint(touch.location(in: self)),
                          radius: Self.contactRadius(of: touch))
        }
        recompute()
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { untrack(touches); recompute() }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        untrack(touches)
        recompute()
    }

    /// Release everything (view removal, edit mode, rotation).
    public func releaseAll() {
        released.formUnion(tracker.keys)
        tracker.removeAll()
        recompute()
    }

    private func untrack(_ touches: Set<UITouch>) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            tracker.ended(key)
            released.remove(key)
        }
    }

    private func canvasPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + canvasOrigin.x, y: point.y + canvasOrigin.y)
    }

    /// The finger's contact radius in points. tvOS has no finger contact, so it reports none.
    private static func contactRadius(of touch: UITouch) -> CGFloat {
#if os(iOS)
        return touch.majorRadius
#else
        return 0
#endif
    }

    private func recompute() {
        let hits = tracker.hits()
        guard hits != current else { return }
        current = hits
        onChange?(hits)
    }
}
#endif

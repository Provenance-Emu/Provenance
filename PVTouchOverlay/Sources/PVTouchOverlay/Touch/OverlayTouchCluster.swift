#if canImport(UIKit)
import UIKit

/// One multi-touch surface over a group of buttons and d-pads. Each event recomputes the
/// union of hits across all live touches and emits only when the set changes.
public final class OverlayTouchCluster: UIView {
    public var controls: [ResolvedControl] = [] {
        didSet { if !live.isEmpty { recompute() } }
    }
    /// Controls are in canvas points and the view may be offset. Set by the host.
    public var canvasOrigin: CGPoint = .zero
    public var onChange: ((Set<OverlayHit>) -> Void)?

    /// Live touches, kept off SwiftUI state for performance.
    private var live: [ObjectIdentifier: CGPoint] = [:]
    /// Touches dropped by `releaseAll()`; their later events are ignored until a new touch begins.
    private var released = Set<ObjectIdentifier>()
    private var current = Set<OverlayHit>()
    private var dpadState: [String: Set<OverlayDPadDirection>] = [:]

    public override init(frame: CGRect) {
        super.init(frame: frame)
#if !os(tvOS)
        isMultipleTouchEnabled = true
#endif
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let canvasPoint = CGPoint(x: point.x + canvasOrigin.x, y: point.y + canvasOrigin.y)
        return OverlayHitTester.topControl(at: canvasPoint, in: controls) != nil
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { released.remove(ObjectIdentifier(touch)) }
        track(touches)
        recompute()
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches); recompute() }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { untrack(touches); recompute() }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        untrack(touches)
        recompute()
    }

    /// Release everything (view removal, edit mode, rotation).
    public func releaseAll() {
        released.formUnion(live.keys)
        live.removeAll()
        recompute()
    }

    private func track(_ touches: Set<UITouch>) {
        for touch in touches where !released.contains(ObjectIdentifier(touch)) {
            let location = touch.location(in: self)
            live[ObjectIdentifier(touch)] = CGPoint(x: location.x + canvasOrigin.x, y: location.y + canvasOrigin.y)
        }
    }

    private func untrack(_ touches: Set<UITouch>) {
        for touch in touches {
            live[ObjectIdentifier(touch)] = nil
            released.remove(ObjectIdentifier(touch))
        }
    }

    private func recompute() {
        let hits = OverlayHitTester.hits(at: Array(live.values), controls: controls, previousDPad: dpadState)
        var next: [String: Set<OverlayDPadDirection>] = [:]
        for case let .dpad(id, direction) in hits { next[id, default: []].insert(direction) }
        dpadState = next
        guard hits != current else { return }
        current = hits
        onChange?(hits)
    }
}
#endif

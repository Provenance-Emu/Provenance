#if canImport(UIKit)
import UIKit

/// Single-touch surface for sticks, triggers, stylus, pointer and trackpad. Reports normalized
/// (0...1, clamped) positions within its bounds.
public final class OverlaySingleTouchSurface: UIView {
    public var onBegan: ((CGPoint) -> Void)?
    public var onMoved: ((CGPoint) -> Void)?
    public var onEnded: (() -> Void)?

    private var tracking: UITouch?

    public override init(frame: CGRect) {
        super.init(frame: frame)
#if !os(tvOS)
        isMultipleTouchEnabled = false
#endif
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking == nil, let touch = touches.first else { return }
        tracking = touch
        onBegan?(normalized(touch))
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = tracking, touches.contains(touch) else { return }
        onMoved?(normalized(touch))
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches) }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches) }

    public func releaseAll() {
        guard tracking != nil else { return }
        tracking = nil
        onEnded?()
    }

    private func finish(_ touches: Set<UITouch>) {
        guard let touch = tracking, touches.contains(touch) else { return }
        tracking = nil
        onEnded?()
    }

    private func normalized(_ touch: UITouch) -> CGPoint {
        let location = touch.location(in: self)
        guard bounds.width > 0, bounds.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: min(max(location.x / bounds.width, 0), 1), y: min(max(location.y / bounds.height, 0), 1))
    }
}
#endif

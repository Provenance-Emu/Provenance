///
/// TouchTrackpadView.swift
/// PVUI
///
/// A UIView subclass that intercepts touch events and forwards them to a
/// `MouseResponder` core as normalised (0–1) mouse coordinates.
///
/// Two interaction modes are supported:
///
/// - **touchpad** (default) — touch movement generates *relative* deltas that
///   accumulate a virtual cursor position, mirroring a laptop trackpad.
///   A single tap sends `leftMouseDown` + `leftMouseUp` at the current
///   cursor position.  A long-press sends right-click.
///
/// - **direct** — each touch maps directly to a normalised screen position.
///   Useful for light-gun and pointer-device cores where 1:1 mapping is
///   expected.
///
/// After updating the core, the view posts `Notification.Name.PVMousePositionDidChange`
/// so the `MouseCursorOverlayView` can reposition without tight coupling.
///

#if canImport(UIKit)
import UIKit
import PVCoreBridge

// MARK: - Touch mode

/// Determines how touch input translates to mouse movement.
@objc public enum VirtualMouseMode: Int {
    /// Relative trackpad: finger movement → delta → accumulated cursor position.
    case touchpad
    /// Direct mapping: touch position → normalised mouse position.
    case direct
}

// MARK: - TouchTrackpadView

/// Transparent UIView that sits over the emulator surface and translates
/// touch input into mouse events forwarded to the provided `MouseResponder`.
public final class TouchTrackpadView: UIView {

    // MARK: Public configuration

    /// The core that will receive `mouseMoved`, `leftMouseDown`, etc.
    public weak var mouseResponder: (AnyObject & MouseResponder)?

    /// How touches should be interpreted.
    public var mode: VirtualMouseMode = .touchpad

    /// Trackpad sensitivity multiplier.  1.0 = 1 screen-point ≡ 1/1000 of normalised unit.
    /// Increase to make the cursor move faster relative to finger speed.
    public var sensitivity: CGFloat = 1.5

    // MARK: Public configuration (viewport gating)

    /// Weak reference to the GPU / game-screen view.
    ///
    /// When non-nil, `hitTest` only returns `self` for touch points that fall
    /// within this view's frame (converted to the trackpad's coordinate space).
    /// Touches outside the game viewport — e.g. on controller-skin buttons or
    /// the virtual keyboard panel — pass straight through to the views beneath.
    public weak var gameViewRef: UIView?

    // MARK: Private state

    /// Accumulated normalised cursor position (0–1 in each axis).
    private var cursorPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)

    /// Previous touch location used to compute deltas in touchpad mode.
    private var previousTouchLocation: CGPoint?

    /// The active touch we are tracking (ignores multi-touch).
    private var trackedTouch: UITouch?

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        backgroundColor = .clear
        #if !os(tvOS)
        isMultipleTouchEnabled = false
        #endif
        isUserInteractionEnabled = true

        // Tap: left click
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        addGestureRecognizer(tap)

        // Long-press: right click
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.require(toFail: tap)
        addGestureRecognizer(longPress)
    }

    // MARK: - Hit-testing: only capture inside the game viewport

    /// Returns `self` only when the touch falls within `gameViewRef`'s on-screen
    /// bounds (i.e. the actual game display area).  Touches outside that region —
    /// on controller-skin buttons, the virtual keyboard, or the menu bar — are
    /// returned as `nil` so UIKit continues searching downward in the view hierarchy.
    ///
    /// This replaces an earlier sibling-iteration approach that was unreliable
    /// because transparent container views (skinContainerView, etc.) respond to
    /// hitTest even for empty/transparent pixels, causing the trackpad to
    /// incorrectly pass through *all* touches including game-viewport ones.
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        guard self.point(inside: point, with: event) else { return nil }

        // If we have a game-view reference, gate touch capture to that region.
        if let gameView = gameViewRef {
            // Convert the game view's frame from its superview's space to ours.
            let gameFrameInSelf: CGRect
            if let gameSuper = gameView.superview {
                gameFrameInSelf = convert(gameView.frame, from: gameSuper)
            } else {
                gameFrameInSelf = gameView.frame
            }
            // Only claim this touch if it is inside the game viewport.
            guard gameFrameInSelf.contains(point) else { return nil }
        }

        return super.hitTest(point, with: event)
    }

    // MARK: - Touch tracking (movement)

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackedTouch == nil, let touch = touches.first else { return }
        trackedTouch = touch

        if mode == .direct {
            let normalised = normalisedPoint(for: touch.location(in: self))
            updateCursor(to: normalised, notify: true)
        } else {
            previousTouchLocation = touch.location(in: self)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }

        switch mode {
        case .direct:
            let normalised = normalisedPoint(for: touch.location(in: self))
            updateCursor(to: normalised, notify: true)

        case .touchpad:
            let current = touch.location(in: self)
            if let prev = previousTouchLocation {
                let deltaX = (current.x - prev.x) / bounds.width  * sensitivity
                let deltaY = (current.y - prev.y) / bounds.height * sensitivity
                var newPos = cursorPosition
                newPos.x = max(0, min(1, newPos.x + deltaX))
                newPos.y = max(0, min(1, newPos.y + deltaY))
                updateCursor(to: newPos, notify: true)
            }
            previousTouchLocation = current
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        trackedTouch = nil
        previousTouchLocation = nil
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouch = nil
        previousTouchLocation = nil
    }

    // MARK: - Gesture handlers

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        if mode == .direct {
            let pt = gesture.location(in: self)
            updateCursor(to: normalisedPoint(for: pt), notify: true)
        }
        NotificationCenter.default.post(name: .PVMouseButtonDidPress, object: nil)
        mouseResponder?.leftMouseDown(atPoint: cursorPosition)
        mouseResponder?.leftMouseUp()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        NotificationCenter.default.post(name: .PVMouseButtonDidPress, object: nil)
        mouseResponder?.rightMouseDown(atPoint: cursorPosition)
        mouseResponder?.rightMouseUp()
    }

    // MARK: - Helpers

    private func normalisedPoint(for point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return point }
        return CGPoint(
            x: max(0, min(1, point.x / bounds.width)),
            y: max(0, min(1, point.y / bounds.height))
        )
    }

    /// Update the tracked cursor position, notify the core and post the overlay notification.
    private func updateCursor(to point: CGPoint, notify: Bool) {
        cursorPosition = point
        mouseResponder?.mouseMoved(atPoint: point)
        if notify {
            NotificationCenter.default.post(
                name: .PVMousePositionDidChange,
                object: nil,
                userInfo: [PVMousePositionKey: NSValue(cgPoint: point)]
            )
        }
    }
}
#endif // canImport(UIKit)

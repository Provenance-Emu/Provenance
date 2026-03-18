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

    /// Explicit game-screen rect in the trackpad's own coordinate space.
    ///
    /// When set (non-nil, non-empty), `hitTest` uses this rect directly instead of
    /// deriving one from `gameViewRef` at call time.  The hosting view controller
    /// should set this whenever the authoritative game-display rect is known —
    /// e.g. after `applyFrameToGPUView` positions the GPU view — so that the
    /// trackpad always uses the correct viewport even before the first layout pass.
    ///
    /// Clear to `nil` to fall back to the live `gameViewRef` frame derivation.
    public var explicitGameViewRect: CGRect?

    // MARK: Private state

    /// Accumulated normalised cursor position (0–1 in each axis).
    private var cursorPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)

    /// Previous touch location used to compute deltas in touchpad mode.
    private var previousTouchLocation: CGPoint?

    /// The active touch we are tracking (ignores multi-touch).
    private var trackedTouch: UITouch?

    /// Location where the tracked touch began — for drag-vs-tap discrimination.
    private var touchBeganLocation: CGPoint?
    /// Timestamp of touchesBegan — for tap duration check.
    private var touchBeganTime: TimeInterval = 0
    /// Becomes true once the finger moves beyond `tapMovementThreshold`.
    private var touchHasDragged = false

    /// Minimum movement (points) that classifies a touch as a drag, suppressing the tap click.
    private let tapMovementThreshold: CGFloat = 10
    /// Maximum touch duration (seconds) that still counts as a tap.
    private let tapMaxDuration: TimeInterval = 0.45

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
        isUserInteractionEnabled = true
#if !os(tvOS)
        // Multi-touch required for 2/3-finger gestures.
        isMultipleTouchEnabled = true

        // 2-finger tap → right click
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTapsRequired = 1
        twoFingerTap.numberOfTouchesRequired = 2
        addGestureRecognizer(twoFingerTap)

        // 3-finger tap → middle click
        let threeFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerTap(_:)))
        threeFingerTap.numberOfTapsRequired = 1
        threeFingerTap.numberOfTouchesRequired = 3
        addGestureRecognizer(threeFingerTap)
#endif

        // Long-press → right click (single-finger fallback)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        addGestureRecognizer(longPress)

        // NOTE: single-finger tap (left click) is handled manually in touchesEnded
        // using drag-distance + duration checks so drags never fire a spurious click.
    }

    // MARK: - Hit-testing: only capture inside the game viewport

    /// Returns `self` only when the touch falls within the game display area.
    /// Touches outside that region — on controller-skin buttons, the virtual
    /// keyboard, or the menu bar — pass straight through to the views beneath.
    ///
    /// The authoritative game rect is resolved in priority order:
    /// 1. `explicitGameViewRect` — set by the VC after `applyFrameToGPUView`.
    /// 2. `gameViewRef` — derived at call time via a full-hierarchy conversion.
    /// 3. If neither is available or the resolved rect is empty, all touches
    ///    pass through (safe default when the viewport is not yet known).
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        guard self.point(inside: point, with: event) else { return nil }

        // Let overlays that are visually above this view handle touches first.
        // UIKit normally processes subviews in reverse order (last-added = topmost),
        // so we yield to any sibling that has a higher zPosition OR appears later
        // in the subview array at the same zPosition (skin containers, toasts, etc.).
        // We only yield if a *descendant* of the sibling claims the touch — if the
        // sibling itself is returned it is an empty/transparent container and we
        // should NOT yield (that would silently swallow the touch).
        if let parent = superview {
            let ownIndex = parent.subviews.firstIndex(of: self) ?? 0
            for sibling in parent.subviews where sibling !== self {
                guard !sibling.isHidden, sibling.alpha > 0.01 else { continue }
                let siblingIndex = parent.subviews.firstIndex(of: sibling) ?? 0
                let isAbove = sibling.layer.zPosition > self.layer.zPosition ||
                    (sibling.layer.zPosition == self.layer.zPosition && siblingIndex > ownIndex)
                if isAbove {
                    let siblingPoint = sibling.convert(point, from: self)
                    if let hit = sibling.hitTest(siblingPoint, with: event), hit !== parent {
                        // When hitTest returns the sibling itself, distinguish between:
                        //   A) A transparent container (e.g. UIHostingController root view
                        //      over an empty skin region) — swallows touches silently → skip.
                        //   B) A genuine interactive leaf (UIButton, UIControl, or a view
                        //      with gesture recognizers, e.g. the SwiftUI keyboard overlay
                        //      close button) — yield to it.
                        if hit === sibling {
                            let isInteractiveLeaf = sibling is UIControl ||
                                !(sibling.gestureRecognizers?.isEmpty ?? true)
                            guard isInteractiveLeaf else { continue }
                        }
                        return hit
                    }
                }
            }
        }

        // Resolve the authoritative game-screen rect in our coordinate space.
        let gameRect: CGRect
        if let explicit = explicitGameViewRect, !explicit.isEmpty {
            // Caller provided an authoritative rect — use it directly.
            gameRect = explicit
        } else if let gameView = gameViewRef {
            // Derive from the live game view using a full-hierarchy coordinate
            // conversion that works regardless of nesting depth.
            let converted = gameView.convert(gameView.bounds, to: self)
            // If the converted rect is empty/zero the viewport is not laid out
            // yet — pass through so UI elements remain reachable.
            guard !converted.isEmpty else { return nil }
            gameRect = converted
        } else {
            // No viewport reference at all — pass all touches through so the
            // views below (skin buttons, pause menu, etc.) remain responsive.
            return nil
        }

        guard gameRect.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }

    // MARK: - Touch tracking (movement)

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Only track single-finger touches; multi-finger combos go to gesture recognizers.
        guard trackedTouch == nil, touches.count == 1, let touch = touches.first else { return }
        trackedTouch = touch
        touchBeganLocation = touch.location(in: self)
        touchBeganTime = touch.timestamp
        touchHasDragged = false

        if mode == .direct {
            let normalised = normalisedPoint(for: touch.location(in: self))
            updateCursor(to: normalised, notify: true)
        } else {
            previousTouchLocation = touch.location(in: self)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }

        // Mark as dragged once the finger travels beyond the tap threshold.
        if !touchHasDragged, let began = touchBeganLocation {
            let loc = touch.location(in: self)
            let dx = loc.x - began.x, dy = loc.y - began.y
            if (dx * dx + dy * dy) > (tapMovementThreshold * tapMovementThreshold) {
                touchHasDragged = true
            }
        }

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
        defer {
            trackedTouch = nil
            previousTouchLocation = nil
            touchBeganLocation = nil
            touchHasDragged = false
        }

        // Fire a left click only when the finger didn't drag and the touch was short.
        let duration = touch.timestamp - touchBeganTime
        if !touchHasDragged && duration < tapMaxDuration {
            if mode == .direct {
                let pt = touch.location(in: self)
                updateCursor(to: normalisedPoint(for: pt), notify: true)
            }
            NotificationCenter.default.post(name: .PVMouseButtonDidPress, object: nil)
            mouseResponder?.leftMouseDown(atPoint: cursorPosition)
            mouseResponder?.leftMouseUp()
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouch = nil
        previousTouchLocation = nil
        touchBeganLocation = nil
        touchHasDragged = false
    }

    // MARK: - Gesture handlers

    /// 2-finger tap → right click.
    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        NotificationCenter.default.post(name: .PVMouseButtonDidPress, object: nil)
        mouseResponder?.rightMouseDown(atPoint: cursorPosition)
        mouseResponder?.rightMouseUp()
    }

    /// 3-finger tap → middle click.
    @objc private func handleThreeFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        mouseResponder?.middleMouseDown?(atPoint: cursorPosition)
        mouseResponder?.middleMouseUp?(atPoint: cursorPosition)
    }

    /// Long-press (single finger) → right click fallback for users who prefer it.
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        // Suppress the tap that would otherwise fire on finger-up.
        touchHasDragged = true
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

///
/// LightGunTouchView.swift
/// PVUI
///
/// A UIView subclass that intercepts touch events and forwards them to a
/// `LightGunResponder` core as normalised (0–1) screen coordinates.
///
/// Touch gesture mapping
/// ---------------------
/// - **Single-finger tap**       → aim + trigger (down + up)
/// - **Single-finger drag**      → aim movement (lightGunMovedToPoint)
/// - **Two-finger tap**          → offscreen reload (lightGunReloadDown + lightGunReloadUp)
/// - **Long press**              → auxiliary button A (e.g. Guncon B, Super Scope pause)
/// - **Double tap**              → start button (e.g. Guncon A / SNES Super Scope start)
///
/// The view uses direct (1:1) coordinate mapping — each touch position is
/// normalised to the game viewport bounds, matching how real light guns aim.
///
/// Offscreen vs. onscreen
/// ----------------------
/// This view only intercepts touches that fall within its bounds (which are set to
/// the game viewport frame). Offscreen shots and reloads are emulated logically:
/// a two-finger tap always sends an explicit reload regardless of position.
/// The `isOffscreen()` helper is reserved for future use if the view is ever
/// sized larger than the viewport to capture true off-screen touches.
///
/// Gestures only activate when `lightGunResponder.gameSupportsLightGun == true`.
///

#if canImport(UIKit) && !os(tvOS)
import UIKit
import PVCoreBridge

// MARK: - LightGunTouchView

/// Transparent UIView that sits over the emulator surface and translates
/// touch input into light gun events forwarded to the provided `LightGunResponder`.
public final class LightGunTouchView: UIView {

    // MARK: Public configuration

    /// The core that will receive light gun events.
    public weak var lightGunResponder: (AnyObject & LightGunResponder)?

    /// Weak reference to the GPU / game-screen view used for offscreen detection.
    ///
    /// When non-nil, touches outside this view's frame are flagged as offscreen
    /// (e.g. PSX Guncon off-screen reload).
    public weak var gameViewRef: UIView?

    /// Explicit game-screen rect in the *superview's* coordinate space.
    ///
    /// Used when `gameViewRef` has not yet been laid out. Set this to the authoritative
    /// game-display rect (typically `gameView.frame` in its superview). Hit testing and
    /// offscreen checks compare superview-space touch points against this rect.
    public var explicitGameViewRect: CGRect?

    // MARK: Private state

    /// The active single-finger touch being tracked for aim/move/tap.
    private var trackedTouch: UITouch?
    /// Location where the tracked touch began (drag-vs-tap discrimination).
    private var touchBeganLocation: CGPoint?
    /// Timestamp of touchesBegan (tap-duration discrimination).
    private var touchBeganTime: TimeInterval = 0
    /// True once the finger travels beyond `tapMovementThreshold`.
    private var touchHasDragged = false
    /// Pending single-tap trigger work item; cancelled when a double-tap is recognized.
    private var pendingSingleTapTrigger: DispatchWorkItem?

    /// Minimum movement (points) that promotes a touch to a drag, suppressing tap.
    private let tapMovementThreshold: CGFloat = 8
    /// Maximum touch duration (seconds) still counted as a tap (not a drag).
    private let tapMaxDuration: TimeInterval = 0.45

    // MARK: - Gesture recognizers

    private var twoFingerTapRecognizer: UITapGestureRecognizer!
    private var doubleTapRecognizer: UITapGestureRecognizer!
    private var longPressRecognizer: UILongPressGestureRecognizer!

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
        isMultipleTouchEnabled = true

        // Two-finger tap → offscreen reload
        let twoFinger = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFinger.numberOfTapsRequired = 1
        twoFinger.numberOfTouchesRequired = 2
        addGestureRecognizer(twoFinger)
        twoFingerTapRecognizer = twoFinger

        // Double tap (single finger) → start button
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        addGestureRecognizer(doubleTap)
        doubleTapRecognizer = doubleTap

        // Long press → auxA button (single-finger)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.numberOfTouchesRequired = 1
        addGestureRecognizer(longPress)
        longPressRecognizer = longPress

        // Single-tap must fail if double-tap succeeds
        // (handled in touchesEnded via duration/drag check to avoid interference)
    }

    // MARK: - Hit-testing

    /// Participates in standard UIKit hit-testing, but only when this view is
    /// visible and the touch is inside its bounds.
    ///
    /// The view is sized to the game viewport frame by `refreshLightGunLayout`,
    /// so touches outside the viewport naturally fall outside the view's bounds
    /// and pass through to underlying controls without any extra gating needed.
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        guard self.point(inside: point, with: event) else { return nil }
        return super.hitTest(point, with: event)
    }

    // MARK: - Touch tracking (aim movement)

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Only track the first single-finger touch; gesture recognizers handle multi.
        guard trackedTouch == nil, touches.count == 1, let touch = touches.first else { return }
        trackedTouch = touch
        touchBeganLocation = touch.location(in: self)
        touchBeganTime = touch.timestamp
        touchHasDragged = false

        let normalised = normalisedPoint(for: touch.location(in: self))
        let offscreen = isOffscreen(touch.location(in: self))
        lightGunResponder?.lightGunMovedToPoint(normalised, isOffscreen: offscreen)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }

        // Promote to drag once the finger moves past the threshold.
        if !touchHasDragged, let began = touchBeganLocation {
            let loc = touch.location(in: self)
            let dx = loc.x - began.x
            let dy = loc.y - began.y
            if (dx * dx + dy * dy) > (tapMovementThreshold * tapMovementThreshold) {
                touchHasDragged = true
            }
        }

        let normalised = normalisedPoint(for: touch.location(in: self))
        let offscreen = isOffscreen(touch.location(in: self))
        lightGunResponder?.lightGunMovedToPoint(normalised, isOffscreen: offscreen)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        defer {
            trackedTouch = nil
            touchBeganLocation = nil
            touchHasDragged = false
        }

        let duration = touch.timestamp - touchBeganTime

        // Schedule trigger only when the finger did not drag and the touch was short.
        // Use a delayed work item so handleDoubleTap can cancel it if a double-tap
        // is recognised after this touchesEnded fires.
        // Cancel any prior pending trigger first — both taps of a double-tap call
        // touchesEnded, so without this the first tap's work item leaks and fires.
        if !touchHasDragged && duration < tapMaxDuration {
            pendingSingleTapTrigger?.cancel()
            let normalised = normalisedPoint(for: touch.location(in: self))
            let offscreen = isOffscreen(touch.location(in: self))
            lightGunResponder?.lightGunMovedToPoint(normalised, isOffscreen: offscreen)
            let workItem = DispatchWorkItem { [weak self] in
                self?.pendingSingleTapTrigger = nil
                self?.lightGunResponder?.lightGunTriggerDown()
                self?.lightGunResponder?.lightGunTriggerUp()
            }
            pendingSingleTapTrigger = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pendingSingleTapTrigger?.cancel()
        pendingSingleTapTrigger = nil
        trackedTouch = nil
        touchBeganLocation = nil
        touchHasDragged = false
    }

    // MARK: - Gesture handlers

    /// Two-finger tap → offscreen reload (supports PSX Guncon, SNES Super Scope, etc.)
    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        lightGunResponder?.lightGunReloadDown?()
        lightGunResponder?.lightGunReloadUp?()
    }

    /// Double tap (single finger) → start button (Guncon A, Super Scope start, Menacer start)
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        // Cancel the delayed single-tap trigger scheduled in touchesEnded.
        pendingSingleTapTrigger?.cancel()
        pendingSingleTapTrigger = nil
        touchHasDragged = true
        lightGunResponder?.lightGunStartDown?()
        lightGunResponder?.lightGunStartUp?()
    }

    /// Long press → auxA button (Guncon B, Super Scope pause button, Menacer aux)
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            // Suppress the tap-trigger path.
            touchHasDragged = true
            let normalised = normalisedPoint(for: gesture.location(in: self))
            let offscreen = isOffscreen(gesture.location(in: self))
            lightGunResponder?.lightGunMovedToPoint(normalised, isOffscreen: offscreen)
            lightGunResponder?.lightGunAuxADown?()
        case .ended, .cancelled, .failed:
            lightGunResponder?.lightGunAuxAUp?()
        default:
            break
        }
    }

    // MARK: - Helpers

    /// Convert a touch point to normalised (0–1) coordinates within the view bounds.
    private func normalisedPoint(for point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(
            x: max(0, min(1, point.x / bounds.width)),
            y: max(0, min(1, point.y / bounds.height))
        )
    }

    /// Returns `true` when `point` (in self's coordinate space) falls outside
    /// the game viewport — indicating an intentional off-screen shot or reload.
    private func isOffscreen(_ point: CGPoint) -> Bool {
        if let gameView = gameViewRef {
            let converted = gameView.convert(gameView.bounds, to: self)
            if !converted.isEmpty {
                return !converted.contains(point)
            }
        }
        if let explicit = explicitGameViewRect, !explicit.isEmpty {
            let pointInSuperview = convert(point, to: superview)
            return !explicit.contains(pointInSuperview)
        }
        // No viewport reference — assume onscreen.
        return false
    }
}
#endif // canImport(UIKit) && !os(tvOS)

//
//  Moveable.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/28/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit
import PVLogging

protocol Moveable: AnyObject {
    var isCustomMoved: Bool { get }
    var inMoveMode: Bool { get set }
    var currentScale: CGFloat { get }
    func didStartMoving()
    func didFinishMoving(velocity: CGPoint)
    /// Clamps a candidate x-origin so the view is never dragged outside its superview.
    func clampedX(for x: CGFloat) -> CGFloat
    /// Clamps a candidate y-origin so the view is never dragged outside its superview.
    func clampedY(for y: CGFloat) -> CGFloat
}

extension Moveable where Self: UIView {
    /// Clamping (rather than the previous "reject the whole delta if it would
    /// leave bounds" approach) means a fast drag that overshoots the edge still
    /// lands exactly at the edge instead of stopping short, and a control that
    /// starts partly out of bounds (e.g. after a screen-size change) can still be
    /// dragged back in along the axis that's already valid.
    func clampedX(for x: CGFloat) -> CGFloat {
        guard let superview = superview else { return x }
        let maxX = max(0, superview.bounds.width - bounds.width)
        return min(max(0, x), maxX)
    }

    func clampedY(for y: CGFloat) -> CGFloat {
        guard let superview = superview else { return y }
        let maxY = max(0, superview.bounds.height - bounds.height)
        return min(max(0, y), maxY)
    }
}

/// Codable struct for storing button position and scale
struct ButtonPosition: Codable {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let identifier: String

    init(view: UIView, scale: CGFloat, identifier: String) {
        self.x = view.frame.origin.x
        self.y = view.frame.origin.y
        self.scale = scale
        self.identifier = identifier
    }
}

public class MovableButtonView: UIView, Moveable {
    /// Distance (points) from a superview edge within which a drag snaps flush to that edge on release.
    static let edgeSnapDistance: CGFloat = 12
    /// Extra clearance (points) added beyond the measured overlap when nudging apart two overlapping controls.
    static let overlapNudgeDistance: CGFloat = 8

    public var isCustomMoved: Bool = false {
        didSet {
            ILOG("isCustomMoved changed to: \(isCustomMoved)")
        }
    }
    private var moveStartTime: TimeInterval?
    private var startMoveFrame: CGRect?
    private var panGestureRecognizer: UIPanGestureRecognizer?
    #if !os(tvOS)
    private var pinchGestureRecognizer: UIPinchGestureRecognizer?
    #endif
    private var initialBounds: CGRect?

    /// The frame this control occupies under the current automatic layout, captured
    /// once (before any saved/custom position is applied) via `captureDefaultFrameIfNeeded()`.
    /// Sibling controls that anchor their own default position off THIS control (e.g. a
    /// shoulder button positioned relative to the D-pad) should read `anchorFrame`
    /// rather than `frame` — otherwise dragging this control would cascade into
    /// repositioning every control anchored to it on the next layout pass.
    private(set) var defaultFrame: CGRect?

    /// Records `frame` as this control's stable default position, if not already recorded.
    /// Call this once, right after creating the control with its algorithmic layout
    /// frame and before `loadSavedPosition()` (which may mark it custom-moved).
    func captureDefaultFrameIfNeeded() {
        if defaultFrame == nil {
            defaultFrame = frame
        }
    }

    /// The frame other controls should read when anchoring their own position to this
    /// one. Equal to `frame` unless the user has custom-moved this control, in which
    /// case it falls back to the pristine `defaultFrame` so a drag never cascades into
    /// repositioning siblings that anchor off this control.
    var anchorFrame: CGRect {
        isCustomMoved ? (defaultFrame ?? frame) : frame
    }

    public private(set) var currentScale: CGFloat = 1.0 {
        didSet {
            DLOG("Scale changed from \(oldValue) to \(currentScale)")
        }
    }

    public override var isUserInteractionEnabled: Bool {
        didSet {
            DLOG("User interaction enabled changed: \(oldValue) -> \(isUserInteractionEnabled)")
            panGestureRecognizer?.isEnabled = isUserInteractionEnabled
        }
    }

    var inMoveMode: Bool = false {
        didSet {
            DLOG("Move mode changed: \(oldValue) -> \(inMoveMode)")
            if inMoveMode {
                setupPanGesture()
                #if !os(tvOS)
                setupPinchGesture()
                #endif
            } else {
                removePanGesture()
#if !os(tvOS)
                removePinchGesture()
#endif
            }
        }
    }

    private func setupPanGesture() {
        DLOG("Setting up pan gesture")
        removePanGesture()

        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.delegate = self
        panGestureRecognizer = gesture
        addGestureRecognizer(gesture)
    }

    private func removePanGesture() {
        DLOG("Removing pan gesture")
        if let gesture = panGestureRecognizer {
            removeGestureRecognizer(gesture)
            panGestureRecognizer = nil
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        let velocity = gesture.velocity(in: superview)

        DLOG("Pan gesture state: \(gesture.state.rawValue), translation: \(translation)")

        switch gesture.state {
        case .began:
            startMoveFrame = frame
            moveStartTime = CACurrentMediaTime()
            didStartMoving()

        case .changed:
            let newX = frame.origin.x + translation.x
            let newY = frame.origin.y + translation.y

            var newFrame = frame
            newFrame.origin.x = clampedX(for: newX)
            newFrame.origin.y = clampedY(for: newY)

            frame = newFrame

        case .ended, .cancelled:
            snapToEdgesIfNeeded()
            resolveOverlapIfNeeded()
            didFinishMoving(velocity: velocity)
            moveStartTime = nil

        default:
            break
        }

        gesture.setTranslation(.zero, in: superview)
    }

    /// Snaps this view flush against a superview edge when the drag ended within
    /// `edgeSnapDistance` of it, so a control the user is clearly trying to dock to
    /// an edge doesn't sit a few stray points off it.
    private func snapToEdgesIfNeeded() {
        guard let superview = superview else { return }
        var newFrame = frame

        if newFrame.minX <= Self.edgeSnapDistance {
            newFrame.origin.x = 0
        } else if superview.bounds.width - newFrame.maxX <= Self.edgeSnapDistance {
            newFrame.origin.x = superview.bounds.width - newFrame.width
        }

        if newFrame.minY <= Self.edgeSnapDistance {
            newFrame.origin.y = 0
        } else if superview.bounds.height - newFrame.maxY <= Self.edgeSnapDistance {
            newFrame.origin.y = superview.bounds.height - newFrame.height
        }

        frame = newFrame
    }

    /// Nudges this view away from any sibling `MovableButtonView` it now overlaps,
    /// pushing along whichever axis has the shallower overlap so the move feels like
    /// a small correction rather than a jump. Re-clamps to the superview afterward
    /// since the nudge itself could push the view back out of bounds near an edge.
    private func resolveOverlapIfNeeded() {
        guard let superview = superview else { return }
        let siblings = superview.subviews.compactMap { $0 as? MovableButtonView }.filter { $0 !== self }
        var newFrame = frame

        for sibling in siblings {
            let overlap = newFrame.intersection(sibling.frame)
            guard overlap.width > 0, overlap.height > 0 else { continue }

            if overlap.width < overlap.height {
                if newFrame.midX < sibling.frame.midX {
                    newFrame.origin.x -= overlap.width + Self.overlapNudgeDistance
                } else {
                    newFrame.origin.x += overlap.width + Self.overlapNudgeDistance
                }
            } else {
                if newFrame.midY < sibling.frame.midY {
                    newFrame.origin.y -= overlap.height + Self.overlapNudgeDistance
                } else {
                    newFrame.origin.y += overlap.height + Self.overlapNudgeDistance
                }
            }
        }

        newFrame.origin.x = clampedX(for: newFrame.origin.x)
        newFrame.origin.y = clampedY(for: newFrame.origin.y)
        frame = newFrame
    }

#if !os(tvOS)
    private func setupPinchGesture() {
        DLOG("Setting up pinch gesture")
        removePinchGesture()

        let gesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        gesture.delegate = self
        pinchGestureRecognizer = gesture
        addGestureRecognizer(gesture)
    }

    private func removePinchGesture() {
        DLOG("Removing pinch gesture")
        if let gesture = pinchGestureRecognizer {
            removeGestureRecognizer(gesture)
            pinchGestureRecognizer = nil
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            initialBounds = bounds

        case .changed:
            guard let initialBounds = initialBounds else { return }

            /// Limit scale between 1.0 and 2.0
            let newScale = min(max(gesture.scale, 1.0), 2.0)
            currentScale = newScale

            /// Calculate new size while maintaining center point
            let center = center
            let newWidth = initialBounds.width * newScale
            let newHeight = initialBounds.height * newScale

            /// Update frame while keeping center constant
            bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
            self.center = center

        case .ended, .cancelled:
            saveScale()
            initialBounds = nil

        default:
            break
        }
    }
#endif

    private func saveScale() {
        guard !positionKey.isEmpty else { return }
        let position = ButtonPosition(view: self, scale: currentScale, identifier: positionKey)
        if let encoded = try? JSONEncoder().encode(position) {
            UserDefaults.standard.set(encoded, forKey: positionKey)
        }
    }

    func didStartMoving() {
        DLOG("Button started moving")
    }

    func didFinishMoving(velocity: CGPoint) {
        DLOG("Button finished moving with velocity: \(velocity)")
        if let startFrame = startMoveFrame, startFrame != frame {
            isCustomMoved = true
            savePosition()
        }
    }

    /// Unique identifier for the control type
    var controlIdentifier: String {
        if let dpad = self as? JSDPad {
            switch dpad.padType {
            case .dpad1:
                return "DPad1"
            case .dpad2:
                return "DPad2"
            case .joystick1:
                return "JoyPad1"
            case .joystick2:
                return "JoyPad2"
            }
        } else if let button = self as? JSButton {
            // Use the button's tag and type to create a unique identifier
            let buttonType = String(describing: type(of: button))
            let buttonTag = tag
            return "\(buttonType)_\(buttonTag)"
        }
        // Fallback for other movable views
        return "\(String(describing: type(of: self)))_\(tag)"
    }

    private var cachedPositionKey: String?

    var positionKey: String {
        // Return cached key if we have one
        if let cached = cachedPositionKey {
            return cached
        }

        // Try to find the controller
        if let controller = findViewController() as? any ControllerVC {
            let systemID = controller.system.identifier
            let key = "ButtonPosition_\(systemID)_\(controlIdentifier)"

            // Cache the successful key
            cachedPositionKey = key
//            VLOG("Generated and cached position key: \(key)")
            return key
        }

        // If we can't find the controller yet, try again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.attemptToGenerateKey()
        }

        WLOG("Could not generate position key - will retry")
        return ""
    }

    private func attemptToGenerateKey() {
        if cachedPositionKey == nil {
            // This will trigger the positionKey computation again
            _ = positionKey
        }
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        // Try to generate key when added to view hierarchy
        attemptToGenerateKey()
        // Try to load position once we're in the view hierarchy
        loadSavedPosition()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        // Only try to load position if we're actually in a window
        if window != nil {
            // Try to generate key when window is available
            attemptToGenerateKey()

            // Delay the position loading slightly to ensure controller is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.loadSavedPosition()
            }
        }
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }

    func loadSavedPosition() {
        // Only proceed if we have a valid key
        guard let key = cachedPositionKey,
              let data = UserDefaults.standard.data(forKey: key),
              let position = try? JSONDecoder().decode(ButtonPosition.self, from: data),
              position.identifier == key else {
            return
        }

        ILOG("Loading saved position for key: \(key)")

        frame.origin.x = position.x
        frame.origin.y = position.y

        if position.scale != 1.0 {
            currentScale = position.scale
            let newWidth = bounds.width * position.scale
            let newHeight = bounds.height * position.scale
            bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        }

        isCustomMoved = true
    }

    private func savePosition() {
        guard let key = cachedPositionKey else {
            WLOG("Attempted to save position without valid key")
            return
        }

        let position = ButtonPosition(view: self, scale: currentScale, identifier: key)
        if let encoded = try? JSONEncoder().encode(position) {
            UserDefaults.standard.set(encoded, forKey: key)
            ILOG("Saved position for key: \(key)")
        }
    }

    // MARK: - NSCoding
    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(frame, forKey: "frame")
        coder.encode(currentScale, forKey: "currentScale")
        coder.encode(isCustomMoved, forKey: "isCustomMoved")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        currentScale = coder.decodeDouble(forKey: "currentScale")
        isCustomMoved = coder.decodeBool(forKey: "isCustomMoved")
        frame = coder.decodeCGRect(forKey: "frame")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MovableButtonView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        DLOG("Checking simultaneous recognition between \(gestureRecognizer) and \(otherGestureRecognizer)")
        // Only allow pan gesture to work exclusively
        return !(gestureRecognizer is UIPanGestureRecognizer || otherGestureRecognizer is UIPanGestureRecognizer)
    }
}

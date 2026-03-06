//
//  MouseCursorOverlayView.swift
//  PVUI
//
//  Created by Claude on behalf of Provenance Emu.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

#if canImport(UIKit) && !os(tvOS)
import UIKit
import PVCoreBridge
import PVLogging

/// A transparent overlay that translates touch/pan gestures into normalised
/// mouse-movement and click events forwarded to a `MouseResponder` core.
///
/// Coordinate system: the normalised point `(0,0)` maps to the top-left of
/// the overlay's `emulationFrame` and `(1,1)` maps to the bottom-right.
public final class MouseCursorOverlayView: UIView {

    // MARK: - Public

    /// The rect (in the overlay's coordinate space) that corresponds to the
    /// emulator's rendered screen.  All touch positions are normalised against
    /// this frame.  Defaults to the overlay's own bounds.
    public var emulationFrame: CGRect = .zero

    /// The core that will receive forwarded mouse events.
    public weak var mouseCore: (AnyObject & MouseResponder)?

    // MARK: - Private

    private let cursorLayer = CAShapeLayer()
    private var cursorPosition: CGPoint = .zero
    private var tapRecognizer: UITapGestureRecognizer!
    private var rightTapRecognizer: UILongPressGestureRecognizer!
    private var panRecognizer: UIPanGestureRecognizer!

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        if emulationFrame == .zero {
            emulationFrame = bounds
        }
    }

    private func setupUI() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        // Cursor dot
        cursorLayer.fillColor = UIColor.white.cgColor
        cursorLayer.strokeColor = UIColor(white: 0.2, alpha: 0.8).cgColor
        cursorLayer.lineWidth = 1
        cursorLayer.shadowColor = UIColor.black.cgColor
        cursorLayer.shadowRadius = 2
        cursorLayer.shadowOpacity = 0.6
        cursorLayer.shadowOffset = CGSize(width: 1, height: 1)
        layer.addSublayer(cursorLayer)
        updateCursorLayer()
    }

    private func updateCursorLayer() {
        let size: CGFloat = 14
        let rect = CGRect(x: cursorPosition.x - size / 2,
                          y: cursorPosition.y - size / 2,
                          width: size, height: size)
        // Arrow-style cursor using a simple circle for now
        cursorLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    // MARK: - Gestures

    private func setupGestures() {
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRecognizer.maximumNumberOfTouches = 1
        addGestureRecognizer(panRecognizer)

        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.numberOfTapsRequired = 1
        addGestureRecognizer(tapRecognizer)

        rightTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        rightTapRecognizer.minimumPressDuration = 0.4
        addGestureRecognizer(rightTapRecognizer)
    }

    // MARK: - Gesture Handlers

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let location = gr.location(in: self)
        cursorPosition = location
        updateCursorLayer()

        let normalised = normalise(point: location)

        switch gr.state {
        case .began, .changed:
            mouseCore?.mouseMoved(atPoint: normalised)
        default:
            break
        }
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        let location = gr.location(in: self)
        cursorPosition = location
        updateCursorLayer()

        let normalised = normalise(point: location)
        mouseCore?.leftMouseDown(atPoint: normalised)
        mouseCore?.leftMouseUp()
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        let location = gr.location(in: self)
        let normalised = normalise(point: location)

        switch gr.state {
        case .began:
            mouseCore?.rightMouseDown(atPoint: normalised)
        case .ended, .cancelled:
            mouseCore?.rightMouseUp()
        default:
            break
        }
    }

    // MARK: - Helpers

    private func normalise(point: CGPoint) -> CGPoint {
        let frame = emulationFrame == .zero ? bounds : emulationFrame
        guard frame.width > 0, frame.height > 0 else { return .zero }
        let x = (point.x - frame.minX) / frame.width
        let y = (point.y - frame.minY) / frame.height
        return CGPoint(x: max(0, min(1, x)), y: max(0, min(1, y)))
    }
}
#endif

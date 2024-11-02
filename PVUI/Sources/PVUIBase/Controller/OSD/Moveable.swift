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
    func didStartMoving()
    func didFinishMoving(velocity: CGPoint)
    func canMoveToX(x: CGFloat) -> Bool
    func canMoveToY(y: CGFloat) -> Bool
}

extension Moveable where Self: UIView {
    func canMoveToX(x: CGFloat) -> Bool {
        guard let superview = superview else { return false }
        let diameter = bounds.size.width
        return x >= 0 && (x + diameter) <= superview.bounds.width
    }

    func canMoveToY(y: CGFloat) -> Bool {
        guard let superview = superview else { return false }
        let diameter = bounds.size.height
        return y >= 0 && (y + diameter) <= superview.bounds.height
    }
}

class MovableButtonView: UIView, Moveable {
    public private(set) var isCustomMoved: Bool = false
    private var moveStartTime: TimeInterval?
    private var startMoveFrame: CGRect?
    private var panGestureRecognizer: UIPanGestureRecognizer?

    override var isUserInteractionEnabled: Bool {
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
            } else {
                removePanGesture()
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
            if canMoveToX(x: newX) {
                newFrame.origin.x = newX
            }
            if canMoveToY(y: newY) {
                newFrame.origin.y = newY
            }

            frame = newFrame

        case .ended, .cancelled:
            didFinishMoving(velocity: velocity)
            moveStartTime = nil

        default:
            break
        }

        gesture.setTranslation(.zero, in: superview)
    }

    func didStartMoving() {
        DLOG("Button started moving")
    }

    func didFinishMoving(velocity: CGPoint) {
        DLOG("Button finished moving with velocity: \(velocity)")
        if let startFrame = startMoveFrame, startFrame != frame {
            isCustomMoved = true
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MovableButtonView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        DLOG("Checking simultaneous recognition between \(gestureRecognizer) and \(otherGestureRecognizer)")
        // Only allow pan gesture to work exclusively
        return !(gestureRecognizer is UIPanGestureRecognizer || otherGestureRecognizer is UIPanGestureRecognizer)
    }
}

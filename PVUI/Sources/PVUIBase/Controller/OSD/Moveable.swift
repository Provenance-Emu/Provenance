//
//  Moveable.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/28/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit
import PVLogging

class MovableButtonView : UIView, Moveable {
    public private(set) var isCustomMoved : Bool = false
    private var moveStartTime: TimeInterval?

    var startMoveFrame : CGRect?
    func didStartMoving() {
        DLOG("Button started moving")
        moveStartTime = CACurrentMediaTime()
        startMoveFrame = frame

        DLOG("Initial frame: \(String(describing: startMoveFrame))")

        if let superMove = superview as? Moveable ?? superview?.superview as? Moveable {
            DLOG("Propagating move start to super view")
            superMove.didStartMoving()
        }
    }

    func didFinishMoving(velocity:CGPoint) {
        if let startTime = moveStartTime {
            let duration = CACurrentMediaTime() - startTime
            DLOG("Button finished moving after \(duration)s with velocity: \(velocity)")
        }

        if let startMoveFrame = startMoveFrame {
            let distance = hypot(frame.origin.x - startMoveFrame.origin.x,
                               frame.origin.y - startMoveFrame.origin.y)
            DLOG("Total movement distance: \(distance)pts")
        }

        if let superMove = superview as? Moveable {
            superMove.didFinishMoving(velocity: velocity)
        }

        if let startMoveFrame = startMoveFrame, startMoveFrame != frame {
            isCustomMoved = true
            DLOG("Button position was customized")
        }

        moveStartTime = nil
    }

	var inMoveMode: Bool = false {
        didSet {
            DLOG("JSButton move mode changed: \(oldValue) -> \(inMoveMode)")
            if inMoveMode {
                DLOG("Disabling normal button behavior for move mode")
            } else {
                DLOG("Restoring normal button behavior")
            }
        }
    }
}

import ObjectiveC

private final class Wrapper<T> {
    let value: T
    init(_ x: T) {
        value = x
    }
}

class Associator {

    static private func wrap<AT>(x: AT) -> Wrapper<AT> {
        return Wrapper(x)
    }

    static func setAssociatedObject<AT>(object: AnyObject, value: AT, associativeKey: UnsafeRawPointer, policy: objc_AssociationPolicy) {
        if let v = value as? NSObject {
            objc_setAssociatedObject(object, associativeKey, v, policy)
        } else {
            objc_setAssociatedObject(object, associativeKey, wrap(x: value), policy)
        }
    }

    static func getAssociatedObject<AT>(object: AnyObject, associativeKey: UnsafeRawPointer) -> AT? {
        if let v = objc_getAssociatedObject(object, associativeKey) as? AT {
            return v
        } else if let v = objc_getAssociatedObject(object, associativeKey) as? Wrapper<AT> {
            return v.value
        } else {
            return nil
        }
    }
}

private class MultiDelegate : NSObject, UIGestureRecognizerDelegate {
    @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        DLOG("Checking simultaneous gesture recognition between \(gestureRecognizer) and \(otherGestureRecognizer)")
        return true
    }
}

public extension UIGestureRecognizer {

    struct PropertyKeys {
        static var blockKey = "BCBlockPropertyKey"
        static var multiDelegateKey = "BCMultiDelegateKey"
    }

    private var block:((_ recognizer:UIGestureRecognizer) -> Void)? {
        get {
            return Associator.getAssociatedObject(object: self, associativeKey:PropertyKeys.blockKey)
        }
        set {
            Associator.setAssociatedObject(object: self, value: newValue, associativeKey:PropertyKeys.blockKey, policy: .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var multiDelegate:MultiDelegate? {
        get {
            return Associator.getAssociatedObject(object: self, associativeKey:PropertyKeys.multiDelegateKey)
        }
        set {
            Associator.setAssociatedObject(object: self, value: newValue, associativeKey:PropertyKeys.multiDelegateKey, policy: .OBJC_ASSOCIATION_RETAIN)
        }
    }

    convenience init(block:@escaping (_ recognizer:UIGestureRecognizer?) -> Void) {
        self.init()
        self.block = block
        self.multiDelegate = MultiDelegate()
        self.delegate = self.multiDelegate
        self.addTarget(self, action: #selector(UIGestureRecognizer.didInteractWithGestureRecognizer(_:)))
    }

    @objc func didInteractWithGestureRecognizer(_ sender:UIGestureRecognizer) {
        self.block?(sender)
    }
}

//
//  Moveable.swift
//  Standard Template Protocols
//
//  Created by Chris O'Neil on 9/20/15.
//  Copyright (c) 2015 Because. All rights reserved.
//

public protocol Moveable : UIView {
    func makeMoveable()
    func didStartMoving()
    func didFinishMoving(velocity:CGPoint)
    func canMoveToX(x:CGFloat) -> Bool
    func canMoveToY(y:CGFloat) -> Bool
    func translateCenter(translation:CGPoint, velocity:CGPoint, startPoint:CGPoint, currentPoint:CGPoint) -> CGPoint
    func animateToMovedTransform(transform:CGAffineTransform)
    var inMoveMode : Bool {get set}
}

public protocol Scalable: UIView {
	func didStartScaling()
	func didFinishScaling()
	func canScalTo(factor: Float) -> Bool

	func translateScale(factor: Float,
						startSizet:CGSize,
						currentSize:CGSize) -> CGSize
	func animateToScaledTransform(transform:CGAffineTransform)
	var inScaleMode : Bool {get set}
}

struct MoveablePropertyKeys {
    static var inMoveModeKey = "inMoveModeKey"
}

public extension Moveable {
//
//	internal(set) var inMoveMode: Bool {
//        get {
//            return Associator.getAssociatedObject(object: self, associativeKey:&MoveablePropertyKeys.inMoveModeKey) ?? false
//        }
//        set {
//            Associator.setAssociatedObject(object: self, value: newValue, associativeKey:&MoveablePropertyKeys.inMoveModeKey, policy: .OBJC_ASSOCIATION_RETAIN)
//        }
//    }

    var isMovable : Bool {
        DLOG("Checking if view is movable")
        if let superMovable = superview as? Moveable {
            DLOG("Found movable superview")
            return true
        }
        if let superMovable = superview?.superview as? Moveable {
            DLOG("Found movable super-superview")
            return true
        }
        DLOG("No movable parent views found")
        return true
    }

    func makeUnmovable() {
		inMoveMode = false

		if !isMovable {
			return
		}

        gestureRecognizers?.filter { return $0 is UIPanGestureRecognizer }.forEach { $0.isEnabled = false }
    }

    func makeMoveable() {
		inMoveMode = true

		DLOG("Making view moveable. isMovable: \(isMovable)")

		if !isMovable {
			DLOG("View is not movable, returning")
			return
		}

        var startPoint:CGPoint = .zero
        var currentPoint:CGPoint = .zero

        if let existingGestures = gestureRecognizers?.filter({ return $0 is UIPanGestureRecognizer }), !existingGestures.isEmpty {
            DLOG("Enabling existing pan gestures")
            existingGestures.forEach { $0.isEnabled = true }
        } else {
            DLOG("Creating new pan gesture recognizer")
            let gestureRecognizer = UIPanGestureRecognizer { [weak self] (recognizer) -> Void in
                guard let self = self else {
                    DLOG("Self deallocated during gesture - aborting")
                    return
                }

                let pan = recognizer as! UIPanGestureRecognizer
                let velocity = pan.velocity(in: self.superview)
                let translation = pan.translation(in: self.superview)

                DLOG("Pan gesture update - velocity: \(velocity), translation: \(translation)")

                switch recognizer?.state {
                case .began:
                    startPoint = self.center
                    currentPoint = self.center
                    self.didStartMoving()
                case .ended, .cancelled, .failed:
                    self.didFinishMoving(velocity: velocity)
                default:
                    let point = self.translateCenter(translation: translation, velocity:velocity, startPoint: startPoint, currentPoint: currentPoint)
                    self.animateToMovedTransform(transform: self.transformFromCenter(center: point, currentPoint: currentPoint))
                    currentPoint = point
                }
            }

            self.addGestureRecognizer(gestureRecognizer)
        }
    }

    func animateToMovedTransform(transform:CGAffineTransform) {
        DLOG("Starting move animation to transform: \(transform)")
        UIView.animate(withDuration: 0.01, animations: { [weak self] in
            guard let self = self else { return }
            self.transform = transform
        }, completion: { finished in
            DLOG("Move animation completed: \(finished)")
        })
    }

    func translateCenter(translation:CGPoint, velocity:CGPoint, startPoint:CGPoint, currentPoint:CGPoint) -> CGPoint {
        DLOG("Translating from \(currentPoint) with translation \(translation)")
        var point = startPoint

        if (self.canMoveToX(x: point.x + translation.x)) {
            point.x += translation.x
            DLOG("X translation allowed to \(point.x)")
        } else {
            point.x = translation.x > 0.0 ? maximumPoint().x : minimumPoint().x
            DLOG("X translation limited to \(point.x)")
        }

        if (self.canMoveToY(y: point.y + translation.y)) {
            point.y += translation.y
            DLOG("Y translation allowed to \(point.y)")
        } else {
            point.y = translation.y > 0.0 ? maximumPoint().y : minimumPoint().y
            DLOG("Y translation limited to \(point.y)")
        }

        DLOG("Final translation point: \(point)")
        return point
    }

    func transformFromCenter(center:CGPoint, currentPoint:CGPoint) -> CGAffineTransform {
        let transform = self.transform.translatedBy(x: center.x - currentPoint.x, y: center.y - currentPoint.y)
        DLOG("Creating transform from center: \(center) to current: \(currentPoint)")
        DLOG("Resulting transform: \(transform)")
        return transform
    }

    func didStartMoving() {
        return
    }

    func didFinishMoving(velocity:CGPoint) {
        return
    }

    func canMoveToX(x:CGFloat) -> Bool {
        DLOG("Checking X movement to \(x)")
        if let superview = superview {
            let superviewFrame = superview.bounds
            let diameter = self.bounds.size.width / 2.0
            DLOG("Superview width: \(superviewFrame.width), button diameter: \(diameter)")
            if x + diameter > superviewFrame.size.width {
                DLOG("X movement rejected - would exceed right boundary")
                return false
            }
            if x - diameter < 0.0 {
                DLOG("X movement rejected - would exceed left boundary")
                return false
            }
        }
        DLOG("X movement allowed")
        return true
    }

    func canMoveToY(y:CGFloat) -> Bool {
        DLOG("Checking Y movement to \(y)")
        if let superviewFrame = self.superview?.frame {
            let diameter = self.frame.size.height / 2.0
            DLOG("Superview height: \(superviewFrame.height), button diameter: \(diameter)")
            if y + diameter > superviewFrame.size.height {
                DLOG("Y movement rejected - would exceed bottom boundary")
                return false
            }
            if y - diameter < 0.0 {
                DLOG("Y movement rejected - would exceed top boundary")
                return false
            }
        }
        DLOG("Y movement allowed")
        return true
    }

    func maximumPoint() -> CGPoint {
        if let superviewFrame = self.superview?.frame {
            let x = superviewFrame.size.width - self.frame.size.width / 2.0
            let y = superviewFrame.size.height - self.frame.size.height / 2.0
            return CGPoint(x: x, y: y)
        } else {
            return CGPoint.zero
        }
    }

    func minimumPoint() -> CGPoint {
        let x = self.frame.size.width / 2.0
        let y = self.frame.size.height / 2.0
        return CGPoint(x: x, y: y)
    }
}

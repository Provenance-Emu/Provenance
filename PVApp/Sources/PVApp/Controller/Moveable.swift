//
//  Moveable.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/28/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

class MovableButtonView : UIView, Moveable {
    public private(set) var isCustomMoved : Bool = false

    //    func canMoveToX(x:CGFloat) -> Bool {
    //        // Don't move buttons in groups
    //        if superview is PVButtonGroupOverlayView {
    //            return false
    //        }
    ////        if let superviewFrame = self.superview?.frame {
    ////            let diameter = self.frame.size.width / 2.0
    ////            if x + diameter > superviewFrame.size.width {
    ////                return false
    ////            }
    ////            if x - diameter < 0.0 {
    ////                return false
    ////            }
    ////        }
    //        return true
    //    }
    //
    //    func canMoveToY(y:CGFloat) -> Bool {
    //        // Don't move buttons in groups
    //        if superview is PVButtonGroupOverlayView {
    //            return false
    //        }
    ////        if let superviewFrame = self.superview?.frame {
    ////            let diameter = self.frame.size.height / 2.0
    ////            if y + diameter > superviewFrame.size.height {
    ////                return false
    ////            }
    ////            if y - diameter < 0.0 {
    ////                return false
    ////            }
    ////        }
    //        return true
    //    }

    var startMoveFrame : CGRect?
    func didStartMoving() {
		startMoveFrame = frame

		if let superMove = superview as? Moveable ?? superview?.superview as? Moveable {
            superMove.didStartMoving()
        }
    }

    func didFinishMoving(velocity:CGPoint) {
        if let superMove = superview as? Moveable {
            superMove.didFinishMoving(velocity: velocity)
        }
        // TODO: When done moving, figure out which quadrant the button is in
        // and generate new contraints to the top left, bottom left, etc so
        // on rotate they will be around the same spot from the closest edges
        if let startMoveFrame = startMoveFrame, startMoveFrame != frame {
            isCustomMoved = true
        }
    }

	var inMoveMode: Bool = false
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
        return true
    }
}

public extension UIGestureRecognizer {

    struct PropertyKeys {
        static var blockKey = "BCBlockPropertyKey"
        static var multiDelegateKey = "BCMultiDelegateKey"
    }

    private var block:((_ recognizer:UIGestureRecognizer) -> Void) {
        get {
            return Associator.getAssociatedObject(object: self, associativeKey:&PropertyKeys.blockKey)!
        }
        set {
            Associator.setAssociatedObject(object: self, value: newValue, associativeKey:&PropertyKeys.blockKey, policy: .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var multiDelegate:MultiDelegate {
        get {
            return Associator.getAssociatedObject(object: self, associativeKey:&PropertyKeys.multiDelegateKey)!
        }
        set {
            Associator.setAssociatedObject(object: self, value: newValue, associativeKey:&PropertyKeys.multiDelegateKey, policy: .OBJC_ASSOCIATION_RETAIN)
        }
    }

    convenience init(block:@escaping (_ recognizer:UIGestureRecognizer) -> Void) {
        self.init()
        self.block = block
        self.multiDelegate = MultiDelegate()
        self.delegate = self.multiDelegate
        self.addTarget(self, action: #selector(UIGestureRecognizer.didInteractWithGestureRecognizer(_:)))
    }

    @objc func didInteractWithGestureRecognizer(_ sender:UIGestureRecognizer) {
        self.block(sender)
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
		if let superMovable = superview as? Moveable {
			return !superMovable.isMovable
		}
		if let superMovable = superview?.superview as? Moveable {
			return !superMovable.isMovable
		}
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

		if !isMovable {
			return
		}

        var startPoint:CGPoint = .zero
        var currentPoint:CGPoint = .zero

        if let existingGestures = gestureRecognizers?.filter({ return $0 is UIPanGestureRecognizer }), !existingGestures.isEmpty {
            existingGestures.forEach { $0.isEnabled = true }
        } else {
            let gestureRecognizer = UIPanGestureRecognizer { [unowned self] (recognizer) -> Void in
                let pan = recognizer as! UIPanGestureRecognizer
                let velocity = pan.velocity(in: self.superview)
                let translation = pan.translation(in: self.superview)
                switch recognizer.state {
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
        UIView.animate(withDuration: 0.01) { () -> Void in
            self.transform = transform
        }
    }

    func translateCenter(translation:CGPoint, velocity:CGPoint, startPoint:CGPoint, currentPoint:CGPoint) -> CGPoint {
        var point = startPoint

        if (self.canMoveToX(x: point.x + translation.x)) {
            point.x += translation.x
        } else {
            point.x = translation.x > 0.0 ? maximumPoint().x : minimumPoint().x
        }

        if (self.canMoveToY(y: point.y + translation.y)) {
            point.y += translation.y
        } else {
            point.y = translation.y > 0.0 ? maximumPoint().y : minimumPoint().y
        }

        return point
    }

    func transformFromCenter(center:CGPoint, currentPoint:CGPoint) -> CGAffineTransform {
        return self.transform.translatedBy(x: center.x - currentPoint.x, y: center.y - currentPoint.y)
    }

    func didStartMoving() {
        return
    }

    func didFinishMoving(velocity:CGPoint) {
        return
    }

    func canMoveToX(x:CGFloat) -> Bool {
//        if let superview = superview {
//            let superviewFrame = superview.bounds
//
//            let diameter = self.bounds.size.width / 2.0
//            if x + diameter > superviewFrame.size.width {
//                return false
//            }
//            if x - diameter < 0.0 {
//                return false
//            }
//        }
        return true
    }

    func canMoveToY(y:CGFloat) -> Bool {
//        if let superviewFrame = self.superview?.frame {
//            let diameter = self.frame.size.height / 2.0
//            if y + diameter > superviewFrame.size.height {
//                return false
//            }
//            if y - diameter < 0.0 {
//                return false
//            }
//        }
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

//
//  UIButton+Haptics.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/5/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import UIKit
import ObjectiveC

@propertyWrapper
public struct AssociatedObject<T> {
    var key: UnsafeRawPointer
    public var wrappedValue: T? {
        get {
            return objc_getAssociatedObject(self, key) as? T
        }
        set {
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public init(wrappedValue: T, key: UnsafeRawPointer) {
        self.key = key
        self.wrappedValue = wrappedValue
    }
}

public extension UIView {
    private enum AssociatedKeys {
        static var feedbackGenerator = "feedbackGenerator"
        static var feedbackOnTouchUp = "feedbackOnTouchUp"
        static var feedbackOnTouchDown = "feedbackOnTouchDown"
    }

    private(set) var feedbackGenerator: UISelectionFeedbackGenerator? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.feedbackGenerator) as? UISelectionFeedbackGenerator
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.feedbackGenerator, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var feedbackOnTouchUp: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.feedbackOnTouchUp) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.feedbackOnTouchUp, newValue, .OBJC_ASSOCIATION_RETAIN)
            refreshFeedbackGenerator()
        }
    }

    var feedbackOnTouchDown: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.feedbackOnTouchDown) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.feedbackOnTouchDown, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            refreshFeedbackGenerator()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if feedbackOnTouchDown, touches.anyTouch(in: self) {
            feedbackGenerator?.selectionChanged()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        if feedbackOnTouchUp, touches.anyTouch(in: self) {
            feedbackGenerator?.selectionChanged()
        }
    }

    private func refreshFeedbackGenerator() {
        switch (feedbackOnTouchUp, feedbackOnTouchDown, feedbackGenerator) {
        case (true, _, .none), (_, true, .none): // if either are enabled and we don't have a generator, make one
            feedbackGenerator = UISelectionFeedbackGenerator()
        case (false, false, .some): // if both are disabled and we do have a generator, clear it
            feedbackGenerator = nil
        case (_, _, _): // no change required
            break
        }
    }
}

private extension Set where Element == UITouch {
    func anyTouch(in view: UIView) -> Bool {
        return lazy
            .map { $0.location(in: view) }
            .contains { view.bounds.contains($0) }
    }
}

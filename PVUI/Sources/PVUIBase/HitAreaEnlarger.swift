//
//  HitAreaEnlarger.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

#if canImport(UIKit)
import UIKit

@objc
public protocol HitAreaEnlarger: AnyObject {
    var hitAreaInset: UIEdgeInsets { get set }
}

public extension HitAreaEnlarger where Self: UIButton {
    var touchAreaEdgeInsets: UIEdgeInsets {
        get {
            if let value = objc_getAssociatedObject(self, &hitAreaInset) as? NSValue {
                var edgeInsets: UIEdgeInsets = .zero
                value.getValue(&edgeInsets)
                return edgeInsets
            } else {
                return .zero
            }
        }
        set(newValue) {
            var newValueCopy = newValue
            let objCType = NSValue(uiEdgeInsets: .zero).objCType
            let value = NSValue(&newValueCopy, withObjCType: objCType)
            objc_setAssociatedObject(self, &hitAreaInset, value, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if touchAreaEdgeInsets == .zero || !isEnabled || isHidden {
            return (self as UIControl).point(inside: point, with: event)
        }

        let relativeFrame = bounds
        let hitFrame = relativeFrame.inset(by: touchAreaEdgeInsets)

        return hitFrame.contains(point)
    }
}
#endif

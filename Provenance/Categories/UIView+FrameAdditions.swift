import UIKit

protocol HitAreaEnlarger : class {
	var hitAreaInset : UIEdgeInsets {get set}
}

extension HitAreaEnlarger where Self:UIButton  {
	var touchAreaEdgeInsets: UIEdgeInsets {
		get {
			if let value = objc_getAssociatedObject(self, &hitAreaInset) as? NSValue {
				var edgeInsets: UIEdgeInsets = .zero
				value.getValue(&edgeInsets)
				return edgeInsets
			}
			else {
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
		if self.touchAreaEdgeInsets == .zero || !self.isEnabled || self.isHidden {
			return (self as UIControl).point(inside: point, with: event)
		}

		let relativeFrame = self.bounds
		let hitFrame = relativeFrame.inset(by: self.touchAreaEdgeInsets)

		return hitFrame.contains(point)
	}
}

public extension UIView {
	func setOrigin(_ origin: CGPoint) {
		var frame: CGRect = self.frame
		frame.origin = origin
		self.frame = frame
	}

	func setOriginX(_ originX: CGFloat) {
		var frame: CGRect = self.frame
		frame.origin.x = originX
		self.frame = frame
	}

	func setOriginY(_ originY: CGFloat) {
		var frame: CGRect = self.frame
		frame.origin.y = originY
		self.frame = frame
	}

	func setSize(_ size: CGSize) {
		var frame: CGRect = self.frame
		frame.size = size
		self.frame = frame
	}

	func setHeight(_ height: CGFloat) {
		var frame: CGRect = self.frame
		frame.size.height = height
		self.frame = frame
	}

	func setWidth(_ width: CGFloat) {
		var frame: CGRect = self.frame
		frame.size.width = width
		self.frame = frame
	}
}

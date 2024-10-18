#if canImport(UIKit)
import UIKit
#endif

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

#if !PMKCocoaPods
import PromiseKit
#endif
import UIKit

@available(iOS 10, tvOS 10, *)
public extension UIViewPropertyAnimator {
    func startAnimation(_: PMKNamespacer) -> Guarantee<UIViewAnimatingPosition> {
        return Guarantee {
            addCompletion($0)
            startAnimation()
        }
    }
}

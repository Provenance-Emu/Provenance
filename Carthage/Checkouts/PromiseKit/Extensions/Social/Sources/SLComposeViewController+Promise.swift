#if !os(OSX)

import Social.SLComposeViewController
import UIKit.UIViewController
#if !PMKCocoaPods
import PromiseKit
#endif

/**
 To import this `UIViewController` category:

    use_frameworks!
    pod "PromiseKit/Social"

 And then in your sources:

    import PromiseKit
*/
extension UIViewController {
    /// Presents the message view controller and resolves with the user action.
    public func promise(_ vc: SLComposeViewController, animated: Bool = true, completion: (() -> Void)? = nil) -> Promise<Void> {
        present(vc, animated: animated, completion: completion)
        return Promise { seal in
            vc.completionHandler = { result in
                if result == .cancelled {
                    seal.reject(SLComposeViewController.PMKError.cancelled)
                } else {
                    seal.fulfill(())
                }
            }
        }
    }
}

extension SLComposeViewController {
    /// Errors representing PromiseKit SLComposeViewController failures
    public enum PMKError: CancellableError {
        /// The user cancelled the view controller.
        case cancelled

        /// - Returns: true
        public var isCancelled: Bool {
            switch self { case .cancelled: return true }
        }
    }
}

#endif

#if !PMKCocoaPods
import PromiseKit
#endif
import UIKit

#if !os(tvOS)

extension UIViewController {
#if swift(>=4.2)
    /// Presents the UIImagePickerController, resolving with the user action.
    public func promise(_ vc: UIImagePickerController, animate: PMKAnimationOptions = [.appear, .disappear], completion: (() -> Void)? = nil) -> Promise<[UIImagePickerController.InfoKey: Any]> {
        let animated = animate.contains(.appear)
        let proxy = UIImagePickerControllerProxy()
        vc.delegate = proxy
        present(vc, animated: animated, completion: completion)
        return proxy.promise.ensure {
            vc.presentingViewController?.dismiss(animated: animated, completion: nil)
        }
    }
#else
    /// Presents the UIImagePickerController, resolving with the user action.
    public func promise(_ vc: UIImagePickerController, animate: PMKAnimationOptions = [.appear, .disappear], completion: (() -> Void)? = nil) -> Promise<[String: Any]> {
        let animated = animate.contains(.appear)
        let proxy = UIImagePickerControllerProxy()
        vc.delegate = proxy
        present(vc, animated: animated, completion: completion)
        return proxy.promise.ensure {
            vc.presentingViewController?.dismiss(animated: animated, completion: nil)
        }
    }
#endif
}

@objc private class UIImagePickerControllerProxy: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
#if swift(>=4.2)
    let (promise, seal) = Promise<[UIImagePickerController.InfoKey: Any]>.pending()
#else
    let (promise, seal) = Promise<[String: Any]>.pending()
#endif
    var retainCycle: AnyObject?

    required override init() {
        super.init()
        retainCycle = self
    }

#if swift(>=4.2)
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        seal.fulfill(info)
        retainCycle = nil
    }
#else
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        seal.fulfill(info)
        retainCycle = nil
    }
#endif

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        seal.reject(UIImagePickerController.PMKError.cancelled)
        retainCycle = nil
    }
}

extension UIImagePickerController {
    /// Errors representing PromiseKit UIImagePickerController failures
    public enum PMKError: CancellableError {
        /// The user cancelled the UIImagePickerController.
        case cancelled
        /// - Returns: true
        public var isCancelled: Bool {
            switch self {
            case .cancelled:
                return true
            }
        }
    }
}

#endif

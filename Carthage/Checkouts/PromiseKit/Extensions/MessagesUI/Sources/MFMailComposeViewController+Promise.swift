import MessageUI.MFMailComposeViewController
import UIKit.UIViewController
#if !PMKCocoaPods
import PromiseKit
#endif

/**
 To import this `UIViewController` category:

    use_frameworks!
    pod "PromiseKit/MessageUI"

 And then in your sources:

    import PromiseKit
*/
extension UIViewController {
    /// Presents the message view controller and resolves with the user action.
    public func promise(_ vc: MFMailComposeViewController, animated: Bool = true, completion:(() -> Void)? = nil) -> Promise<MFMailComposeResult> {
        let proxy = PMKMailComposeViewControllerDelegate()
        proxy.retainCycle = proxy
        vc.mailComposeDelegate = proxy
        present(vc, animated: animated, completion: completion)
        _ = proxy.promise.ensure {
            self.dismiss(animated: animated, completion: nil)
        }
        return proxy.promise
    }
}

extension MFMailComposeViewController {
    /// Errors representing PromiseKit MFMailComposeViewController failures
    public enum PMKError: CancellableError, CustomStringConvertible {
        /// The user cancelled sending mail
        case cancelled
        case failed

        /// - Returns: true
        public var isCancelled: Bool {
            switch self {
            case .cancelled:
                return true
            case .failed:
                return false
            }
        }
        
        public var description: String {
            switch self {
            case .failed:
                return "The attempt to save or send the message was unsuccessful."
            case .cancelled:
                return "The mail was cancelled"
            }
                
        }
    }
}

private class PMKMailComposeViewControllerDelegate: NSObject, MFMailComposeViewControllerDelegate, UINavigationControllerDelegate {

    let (promise, seal) = Promise<MFMailComposeResult>.pending()
    var retainCycle: NSObject?

    @objc func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        defer { retainCycle = nil }

        if let error = error {
            seal.reject(error)
        } else {
            switch result {
            case .failed:
                seal.reject(MFMailComposeViewController.PMKError.failed)
            case .cancelled:
                seal.reject(MFMailComposeViewController.PMKError.cancelled)
            default:
                seal.fulfill(result)
            }
        }
    }
}

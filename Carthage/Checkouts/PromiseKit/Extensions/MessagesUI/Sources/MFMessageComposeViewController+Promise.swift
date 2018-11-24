import Foundation
import MessageUI.MFMessageComposeViewController
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
    public func promise(_ vc: MFMessageComposeViewController, animated: Bool = true, completion:(() -> Void)? = nil) -> Promise<Void> {
        let proxy = PMKMessageComposeViewControllerDelegate()
        proxy.retainCycle = proxy
        vc.messageComposeDelegate = proxy
        present(vc, animated: animated, completion: completion)
        _ = proxy.promise.ensure {
            vc.dismiss(animated: animated, completion: nil)
        }
        return proxy.promise
    }
}

extension MFMessageComposeViewController {
    /// Errors representing PromiseKit MFMailComposeViewController failures
    public enum PMKError: CancellableError, CustomStringConvertible {
        /// The user cancelled sending the message
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
                return "The message was cancelled"
            }
                
        }
    }
}

private class PMKMessageComposeViewControllerDelegate: NSObject, MFMessageComposeViewControllerDelegate, UINavigationControllerDelegate {

    let (promise, seal) = Promise<Void>.pending()
    var retainCycle: NSObject?

    @objc func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        defer { retainCycle = nil }

        switch result {
        case .sent:
            seal.fulfill(())
        case .failed:
            seal.reject(MFMessageComposeViewController.PMKError.failed)
        case .cancelled:
            seal.reject(MFMessageComposeViewController.PMKError.cancelled)
        }
    }
}

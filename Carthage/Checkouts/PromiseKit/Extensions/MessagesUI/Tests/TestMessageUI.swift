import PMKMessagesUI
import PromiseKit
import MessageUI
import XCTest
import UIKit


class MessageUITests: XCTestCase {
    var rootvc: UIViewController!

    func test_can_cancel_mail_composer() {
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        var order = false

        let mailer = MFMailComposeViewController()
        mailer.setToRecipients(["mxcl@me.com"])

        let promise = rootvc.promise(mailer, animated: false, completion: {
            after(seconds: 0.25).done { _ in
                XCTAssertFalse(order)
                let button = mailer.viewControllers[0].navigationItem.leftBarButtonItem!
                UIControl().sendAction(button.action!, to: button.target, for: nil)
                ex1.fulfill()
            }
        })
        promise.catch { _ -> Void in
            XCTFail()
        }
        promise.catch(policy: .allErrors) { _ -> Void in
            // seems necessary to give vc stack a bit of time
            after(seconds: 0.5).done(ex2.fulfill)
            order = true
        }
        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertNil(rootvc.presentedViewController)
    }

    func test_can_cancel_message_composer() {
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        var order = false

        let messager = MFMessageComposeViewController()

        let promise = rootvc.promise(messager, animated: false, completion: {
            after(seconds: 0.25).done { _ in
                XCTAssertFalse(order)

                let button = messager.viewControllers[0].navigationItem.leftBarButtonItem!
                UIControl().sendAction(button.action!, to: button.target, for: nil)
                ex1.fulfill()
            }
        })

        promise.catch { _ -> Void in
            XCTFail()
        }
        promise.catch(policy: .allErrors) { _ -> Void in
            // seems necessary to give vc stack a bit of time
            after(seconds: 0.5).done(ex2.fulfill)
            order = true
        }
        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertNil(rootvc.presentedViewController)
    }
}

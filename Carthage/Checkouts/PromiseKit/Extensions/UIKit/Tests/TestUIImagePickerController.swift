import PromiseKit
import PMKUIKit
import XCTest
import UIKit

#if os(iOS)

class Test_UIImagePickerController_Swift: XCTestCase {
    func test() {
        class Mock: UIViewController {
            var info = [String:AnyObject]()

            override func present(_ vc: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
                let ipc = vc as! UIImagePickerController
                after(seconds: 0.05).done {
                    ipc.delegate?.imagePickerController?(ipc, didFinishPickingMediaWithInfo: self.info)
                }
            }
        }

        let (originalImage, editedImage) = (UIImage(), UIImage())

        let mockvc = Mock()
        mockvc.info = [UIImagePickerControllerOriginalImage: originalImage, UIImagePickerControllerEditedImage: editedImage]

        let ex = expectation(description: "")
        mockvc.promise(UIImagePickerController(), animate: []).done { _ in
            ex.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
}

#endif

import XCTest
import UIKit

extension XCTestCase {
    var rootvc: UIViewController {
        return UIApplication.shared.keyWindow!.rootViewController!
    }

    override open func setUp() {
        UIApplication.shared.keyWindow!.rootViewController = UIViewController()
    }

    override open func tearDown() {
        UIApplication.shared.keyWindow!.rootViewController = nil
    }
}

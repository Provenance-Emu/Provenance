import PMKAddressBook
import AddressBook
import PromiseKit
import XCTest

class AddressBookTests: XCTestCase {
    func test() {
        let ex = expectation(description: "")
        ABAddressBookRequestAccess().done { (auth: ABAuthorizationStatus) in
            XCTAssertEqual(auth, ABAuthorizationStatus.authorized)
            ex.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}

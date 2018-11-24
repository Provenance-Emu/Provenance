import PMKEventKit
import PromiseKit
import EventKit
import XCTest

class Test_EventKit_Swift: XCTestCase {
    func test() {
        #if os(OSX)
            //FIXME can't make this succeed on Travis :(
            // needs Entitlements, but then I can't get it to sign
            // so, we'll just test linkage
            EKEventStoreRequestAccess()
        #else
            let ex = expectation(description: "")
            EKEventStoreRequestAccess().ensure(ex.fulfill)
            waitForExpectations(timeout: 30)
        #endif
    }
}

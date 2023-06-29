import XCTest

import RxRealmTests

var tests = [XCTestCaseEntry]()
tests += RxRealmLinkingObjectsTests.allTests()
tests += RxRealmListTests.allTests()
tests += RxRealmObjectTests.allTests()
tests += RxRealmOnQueueTests.allTests()
tests += RxRealmRealmTests.allTests()
tests += RxRealmResultsTests.allTests()
tests += RxRealm_Tests.allTests()
tests += RxRealmWriteSinks.allTests()
XCTMain(tests)

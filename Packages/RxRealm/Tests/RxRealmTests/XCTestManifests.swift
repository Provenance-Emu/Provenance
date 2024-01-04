import XCTest

#if !canImport(ObjectiveC)
  public func allTests() -> [XCTestCaseEntry] {
    return [
      testCase(RxRealmLinkingObjectsTests.allTests),
      testCase(RxRealmListTests.allTests),
      testCase(RxRealmObjectTests.allTests),
      testCase(RxRealmOnQueueTests.allTests),
      testCase(RxRealmRealmTests.allTests),
      testCase(RxRealmResultsTests.allTests),
      testCase(RxRealm_Tests.allTests),
      testCase(RxRealmWriteSinks.allTests)
    ]
  }
#endif

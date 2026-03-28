import Testing
import Foundation
@testable import PVControllerDSU

/// Tests for DSUFileStorage — verifies the module uses Caches, not Documents.
struct DSUFileStorageTests {

    @Test("baseURL is inside the Caches directory")
    func testBaseURLIsInCaches() throws {
        let base = DSUFileStorage.baseURL
        let cachesURL = try #require(
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        )
        // The base URL must be a descendant of the Caches directory.
        #expect(base.path.hasPrefix(cachesURL.path))
    }

    @Test("baseURL last path component is 'PVControllerDSU'")
    func testBaseURLName() {
        #expect(DSUFileStorage.baseURL.lastPathComponent == "PVControllerDSU")
    }

    @Test("baseURL does NOT point into Documents")
    func testBaseURLNotDocuments() {
        let documentsURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let base = DSUFileStorage.baseURL.path
        for docURL in documentsURLs {
            #expect(!base.hasPrefix(docURL.path),
                    "DSU data must never be written to Documents (restricted on tvOS)")
        }
    }

    @Test("baseURL is consistent across multiple calls")
    func testBaseURLIsStable() {
        #expect(DSUFileStorage.baseURL == DSUFileStorage.baseURL)
    }
}

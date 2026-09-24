import XCTest
@testable import PVQuickLookSupport

final class ArtworkResolverTests: XCTestCase {
    private var container: URL!

    override func setUp() {
        super.setUp()
        container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: container)
        super.tearDown()
    }

    func testMD5MatchesKnownVector() {
        XCTAssertEqual(ArtworkResolver.md5Hex("hello"), "5d41402abc4b2a76b9719d911017c592")
    }

    func testResolvesDocumentsPVCacheFirst() throws {
        let hash = ArtworkResolver.md5Hex("art-key")
        let docs = container.appendingPathComponent("Documents/PVCache/\(hash)")
        let caches = container.appendingPathComponent("Caches/PVCache/\(hash)")
        for u in [docs, caches] {
            try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([1]).write(to: u)
        }
        XCTAssertEqual(ArtworkResolver.fileURL(forKey: "art-key", containerURL: container), docs)
        try FileManager.default.removeItem(at: docs)
        XCTAssertEqual(ArtworkResolver.fileURL(forKey: "art-key", containerURL: container), caches)
    }

    func testMissingReturnsNil() {
        XCTAssertNil(ArtworkResolver.fileURL(forKey: "nothing", containerURL: container))
        XCTAssertNil(ArtworkResolver.fileURL(forKey: "", containerURL: container))
        XCTAssertNil(ArtworkResolver.fileURL(forKey: "x", containerURL: nil))
    }
}

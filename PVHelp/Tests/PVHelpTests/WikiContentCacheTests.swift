import XCTest
@testable import PVHelp

final class WikiContentCacheTests: XCTestCase {
    var cache: WikiContentCache!

    override func setUp() {
        super.setUp()
        cache = WikiContentCache()
        cache.clearAll()
    }

    override func tearDown() {
        cache.clearAll()
        super.tearDown()
    }

    func testCachePageReadWrite() {
        let content = "# Test\n\nHello world"
        let path = "test/page.md"

        XCTAssertNil(cache.cachedPage(for: path))

        cache.cachePage(content, for: path)
        let cached = cache.cachedPage(for: path)
        XCTAssertEqual(cached, content)
    }

    func testCachePageValidity() {
        let path = "test/valid.md"
        cache.cachePage("content", for: path)
        XCTAssertTrue(cache.isPageCacheValid(for: path))
    }

    func testCachePageInvalidWhenMissing() {
        XCTAssertFalse(cache.isPageCacheValid(for: "nonexistent.md"))
    }

    func testCacheNavigationTreeReadWrite() throws {
        let tree = WikiNavigationTree(sections: [
            WikiSection(title: "Test", items: [
                WikiNavItem(title: "Page", path: "page.md")
            ])
        ])

        XCTAssertNil(cache.cachedNavigationTree())

        cache.cacheNavigationTree(tree)
        let cached = cache.cachedNavigationTree()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.sections.count, 1)
        XCTAssertEqual(cached?.sections[0].items[0].title, "Page")
    }

    func testNavigationCacheValidity() {
        let tree = WikiNavigationTree(sections: [])
        cache.cacheNavigationTree(tree)
        XCTAssertTrue(cache.isNavigationCacheValid())
    }

    func testClearAll() {
        cache.cachePage("content", for: "test.md")
        cache.cacheNavigationTree(WikiNavigationTree(sections: []))

        cache.clearAll()

        XCTAssertNil(cache.cachedPage(for: "test.md"))
        XCTAssertNil(cache.cachedNavigationTree())
    }
}

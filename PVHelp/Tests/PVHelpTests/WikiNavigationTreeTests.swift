import XCTest
@testable import PVHelp

final class WikiNavigationTreeTests: XCTestCase {

    let sampleSummary = """
    # Table of contents

    * [Welcome](README.md)
    * [FAQ](faqs.md)

    ## Getting Started

    * [Installing](installation/README.md)
      * [App Store](installation/app-store.md)
      * [Sideloading](installation/sideloading.md)
        * [Building from Source](installation/building.md)
    * [BIOS Requirements](bios.md)

    ## Using Provenance

    * [Controllers](info/controllers/README.md)
      * [Supported Controllers](info/controllers/supported.md)
    * [Cheats](info/cheats.md)
    """

    func testParseSections() {
        let tree = WikiNavigationTree.parse(markdown: sampleSummary)

        // Root section (items before first ##) + 2 named sections
        XCTAssertEqual(tree.sections.count, 3)
        XCTAssertEqual(tree.sections[0].title, "")
        XCTAssertEqual(tree.sections[1].title, "Getting Started")
        XCTAssertEqual(tree.sections[2].title, "Using Provenance")
    }

    func testParseRootItems() {
        let tree = WikiNavigationTree.parse(markdown: sampleSummary)
        let root = tree.sections[0]

        XCTAssertEqual(root.items.count, 2)
        XCTAssertEqual(root.items[0].title, "Welcome")
        XCTAssertEqual(root.items[0].path, "README.md")
        XCTAssertEqual(root.items[1].title, "FAQ")
        XCTAssertEqual(root.items[1].path, "faqs.md")
    }

    func testParseNestedItems() {
        let tree = WikiNavigationTree.parse(markdown: sampleSummary)
        let gettingStarted = tree.sections[1]

        XCTAssertEqual(gettingStarted.items.count, 2)

        let installing = gettingStarted.items[0]
        XCTAssertEqual(installing.title, "Installing")
        XCTAssertEqual(installing.children.count, 2)
        XCTAssertEqual(installing.children[0].title, "App Store")
        XCTAssertEqual(installing.children[1].title, "Sideloading")

        // Deeply nested
        XCTAssertEqual(installing.children[1].children.count, 1)
        XCTAssertEqual(installing.children[1].children[0].title, "Building from Source")
    }

    func testSkipsExternalLinks() {
        let markdown = """
        ## Help

        * [Contributing](help/contribute.md)
        * [Release Notes](https://github.com/Provenance-Emu/Provenance/releases)
        * [Troubleshooting](help/troubleshooting.md)
        """

        let tree = WikiNavigationTree.parse(markdown: markdown)
        XCTAssertEqual(tree.sections.count, 1)
        XCTAssertEqual(tree.sections[0].items.count, 2) // external link skipped
        XCTAssertEqual(tree.sections[0].items[0].title, "Contributing")
        XCTAssertEqual(tree.sections[0].items[1].title, "Troubleshooting")
    }

    func testEmptyInput() {
        let tree = WikiNavigationTree.parse(markdown: "")
        XCTAssertTrue(tree.sections.isEmpty)
    }

    func testCodable() throws {
        let tree = WikiNavigationTree.parse(markdown: sampleSummary)
        let data = try JSONEncoder().encode(tree)
        let decoded = try JSONDecoder().decode(WikiNavigationTree.self, from: data)
        XCTAssertEqual(decoded.sections.count, tree.sections.count)
        XCTAssertEqual(decoded.sections[1].items[0].children.count, 2)
    }
}

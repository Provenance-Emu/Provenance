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
      * [AltStore](installation/altstore.md)
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
        // AltStore is blocked by keyword filter, only App Store remains
        XCTAssertEqual(installing.children.count, 1)
        XCTAssertEqual(installing.children[0].title, "App Store")
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

    func testBlocksAppStoreUnsafePages() {
        let markdown = """
        ## Getting Started

        * [App Store](installation-and-usage/installing-provenance/app-store.md)
        * [Sideloading](installation-and-usage/installing-provenance/sideloading.md)
        * [Building from Source](installation-and-usage/installing-provenance/building-from-source.md)
        * [Alternative Methods](installation-and-usage/installing-provenance/advanced.md)

        ## Advanced

        * [Virtualizing macOS](info/miscellaneous/virtualizing-macos.md)
        * [Launch ROMs via URL](info/miscellaneous/launch-roms-via-url.md)

        ## Help

        * [Troubleshooting](help/troubleshooting.md)
        * [UDID Registration](help/udid.md)
        """

        let tree = WikiNavigationTree.parse(markdown: markdown)

        // Getting Started: only App Store should remain
        let gettingStarted = tree.sections[0]
        XCTAssertEqual(gettingStarted.items.count, 1)
        XCTAssertEqual(gettingStarted.items[0].title, "App Store")

        // Advanced: only Launch ROMs should remain
        let advanced = tree.sections[1]
        XCTAssertEqual(advanced.items.count, 1)
        XCTAssertEqual(advanced.items[0].title, "Launch ROMs via URL")

        // Help: only Troubleshooting should remain
        let help = tree.sections[2]
        XCTAssertEqual(help.items.count, 1)
        XCTAssertEqual(help.items[0].title, "Troubleshooting")
    }

    func testBlockedSectionDroppedWhenEmpty() {
        let markdown = """
        ## Blocked Section

        * [Sideloading](installation-and-usage/installing-provenance/sideloading.md)

        ## Good Section

        * [Cheats](info/cheats.md)
        """

        let tree = WikiNavigationTree.parse(markdown: markdown)
        // Blocked Section should be entirely dropped
        XCTAssertEqual(tree.sections.count, 1)
        XCTAssertEqual(tree.sections[0].title, "Good Section")
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
        XCTAssertEqual(decoded.sections[1].items[0].children.count, 1)
    }
}

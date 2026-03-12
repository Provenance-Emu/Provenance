import XCTest
@testable import PVHelp

final class GitBookPreprocessorTests: XCTestCase {

    // MARK: - Front Matter

    func testStripFrontMatter() {
        let input = """
        ---
        description: Some description
        layout: landing
        ---

        # Welcome

        Hello world
        """

        let result = GitBookPreprocessor.stripFrontMatter(input)
        XCTAssertFalse(result.contains("---"))
        XCTAssertFalse(result.contains("description:"))
        XCTAssertTrue(result.contains("# Welcome"))
        XCTAssertTrue(result.contains("Hello world"))
    }

    func testStripFrontMatterNoFrontMatter() {
        let input = "# Just a title\n\nSome content"
        let result = GitBookPreprocessor.stripFrontMatter(input)
        XCTAssertEqual(result, input)
    }

    // MARK: - Hint Blocks

    func testConvertInfoHintBlock() {
        let input = """
        Some text before

        {% hint style="info" %}
        This is an info hint.
        {% endhint %}

        Some text after
        """

        let result = GitBookPreprocessor.convertHintBlocks(input)
        XCTAssertFalse(result.contains("{% hint"))
        XCTAssertFalse(result.contains("{% endhint %}"))
        XCTAssertTrue(result.contains("**Info**"))
        XCTAssertTrue(result.contains("> This is an info hint."))
        XCTAssertTrue(result.contains("Some text before"))
        XCTAssertTrue(result.contains("Some text after"))
    }

    func testConvertWarningHintBlock() {
        let input = """
        {% hint style="warning" %}
        Be careful!
        {% endhint %}
        """

        let result = GitBookPreprocessor.convertHintBlocks(input)
        XCTAssertTrue(result.contains("**Warning**"))
        XCTAssertTrue(result.contains("> Be careful!"))
    }

    func testConvertMultipleHintBlocks() {
        let input = """
        {% hint style="info" %}
        Info content
        {% endhint %}

        {% hint style="success" %}
        Success content
        {% endhint %}
        """

        let result = GitBookPreprocessor.convertHintBlocks(input)
        XCTAssertTrue(result.contains("**Info**"))
        XCTAssertTrue(result.contains("**Success**"))
    }

    // MARK: - Tab Blocks

    func testConvertTabBlocksStripsTabsAndEndtabs() {
        let input = """
        {% tabs %}
        {% tab title="iOS" %}
        Install from the App Store.
        {% endtab %}
        {% endtabs %}
        """

        let result = GitBookPreprocessor.convertTabBlocks(input)
        XCTAssertFalse(result.contains("{% tabs %}"))
        XCTAssertFalse(result.contains("{% endtabs %}"))
        XCTAssertFalse(result.contains("{% endtab %}"))
    }

    func testConvertTabBlocksTitleBecomesHeader() {
        let input = """
        {% tabs %}
        {% tab title="iOS" %}
        iOS content here.
        {% endtab %}
        {% tab title="tvOS" %}
        tvOS content here.
        {% endtab %}
        {% endtabs %}
        """

        let result = GitBookPreprocessor.convertTabBlocks(input)
        XCTAssertTrue(result.contains("### iOS"))
        XCTAssertTrue(result.contains("### tvOS"))
        XCTAssertTrue(result.contains("iOS content here."))
        XCTAssertTrue(result.contains("tvOS content here."))
    }

    func testConvertTabBlocksEndtabBecomesSeparator() {
        let input = "{% tab title=\"A\" %}\ncontent\n{% endtab %}"
        let result = GitBookPreprocessor.convertTabBlocks(input)
        XCTAssertTrue(result.contains("---"))
    }

    func testStripsRemainingLiquidTags() {
        let input = "Some text {% unknown tag %} more text"
        let result = GitBookPreprocessor.convertTabBlocks(input)
        XCTAssertFalse(result.contains("{%"))
        XCTAssertTrue(result.contains("Some text"))
        XCTAssertTrue(result.contains("more text"))
    }

    // MARK: - HTML Tables

    func testConvertSimpleHTMLTable() {
        let input = """
        <table>
        <tr><th>Name</th><th>Value</th></tr>
        <tr><td>iOS</td><td>17</td></tr>
        <tr><td>tvOS</td><td>17</td></tr>
        </table>
        """

        let result = GitBookPreprocessor.convertHTMLTables(input)
        XCTAssertFalse(result.contains("<table>"))
        XCTAssertFalse(result.contains("<tr>"))
        XCTAssertFalse(result.contains("<th>"))
        XCTAssertFalse(result.contains("<td>"))
        XCTAssertTrue(result.contains("Name"))
        XCTAssertTrue(result.contains("Value"))
        XCTAssertTrue(result.contains("iOS"))
        XCTAssertTrue(result.contains("17"))
        // Should have markdown table separator
        XCTAssertTrue(result.contains("---"))
        XCTAssertTrue(result.contains("|"))
    }

    func testConvertHTMLTableEdgeCaseEmpty() {
        let input = "<table></table>"
        let result = GitBookPreprocessor.convertHTMLTables(input)
        // Should produce empty or just whitespace — not crash
        XCTAssertFalse(result.contains("<table>"))
    }

    // MARK: - Details/Summary

    func testConvertDetailsBlock() {
        let input = """
        <details>
        <summary>Click to expand</summary>
        Hidden content here.
        </details>
        """

        let result = GitBookPreprocessor.convertHTMLDetailsBlocks(input)
        XCTAssertFalse(result.contains("<details>"))
        XCTAssertFalse(result.contains("<summary>"))
        XCTAssertTrue(result.contains("**Click to expand**"))
        XCTAssertTrue(result.contains("Hidden content here."))
    }

    func testConvertDetailsBlockEmptyContent() {
        let input = "<details><summary>Title</summary></details>"
        let result = GitBookPreprocessor.convertHTMLDetailsBlocks(input)
        XCTAssertTrue(result.contains("**Title**"))
        XCTAssertFalse(result.contains("<details>"))
    }

    // MARK: - Inline HTML Tags

    func testConvertStrongTag() {
        let input = "This is <strong>bold text</strong> here."
        let result = GitBookPreprocessor.convertHTMLInlineTags(input)
        XCTAssertTrue(result.contains("**bold text**"))
        XCTAssertFalse(result.contains("<strong>"))
    }

    func testConvertEmTag() {
        let input = "This is <em>italic</em> text."
        let result = GitBookPreprocessor.convertHTMLInlineTags(input)
        XCTAssertTrue(result.contains("*italic*"))
        XCTAssertFalse(result.contains("<em>"))
    }

    func testConvertBoldTag() {
        let input = "<b>Bold</b> content"
        let result = GitBookPreprocessor.convertHTMLInlineTags(input)
        XCTAssertTrue(result.contains("**Bold**"))
        XCTAssertFalse(result.contains("<b>"))
    }

    func testConvertBrTag() {
        let input = "Line one<br>Line two"
        let result = GitBookPreprocessor.convertHTMLInlineTags(input)
        XCTAssertFalse(result.contains("<br>"))
        XCTAssertTrue(result.contains("\n"))
    }

    func testStripsUnknownHTMLTags() {
        let input = "<div class=\"foo\">Content</div>"
        let result = GitBookPreprocessor.convertHTMLInlineTags(input)
        XCTAssertFalse(result.contains("<div"))
        XCTAssertTrue(result.contains("Content"))
    }

    // MARK: - Image Paths

    func testResolveImagePaths() {
        let input = "![Screenshot](.gitbook/assets/screenshot.png)"
        let result = GitBookPreprocessor.resolveImagePaths(input)
        XCTAssertTrue(result.contains("https://raw.githubusercontent.com/Provenance-EMU/wiki/master/.gitbook/assets/screenshot.png"))
        XCTAssertFalse(result.contains("(.gitbook/"))
    }

    func testResolveRelativeImagePaths() {
        let input = "![Alt](../.gitbook/assets/image.jpg)"
        let result = GitBookPreprocessor.resolveImagePaths(input)
        XCTAssertTrue(result.contains("https://raw.githubusercontent.com/Provenance-EMU/wiki/master/.gitbook/assets/image.jpg"))
    }

    func testResolveMultipleImages() {
        let input = """
        ![First](.gitbook/assets/first.png)
        Some text
        ![Second](.gitbook/assets/second.png)
        """

        let result = GitBookPreprocessor.resolveImagePaths(input)
        XCTAssertTrue(result.contains("first.png"))
        XCTAssertTrue(result.contains("second.png"))
        XCTAssertFalse(result.contains("(.gitbook/"))
    }

    // MARK: - Full Pipeline

    func testProcessFullPipeline() {
        let input = """
        ---
        description: Test page
        ---

        # Test Page

        {% hint style="info" %}
        Important info here.
        {% endhint %}

        ![Screenshot](.gitbook/assets/test.png)
        """

        let result = GitBookPreprocessor.process(input)
        XCTAssertFalse(result.contains("---"))
        XCTAssertFalse(result.contains("{% hint"))
        XCTAssertFalse(result.contains("(.gitbook/"))
        XCTAssertTrue(result.contains("# Test Page"))
        XCTAssertTrue(result.contains("**Info**"))
        XCTAssertTrue(result.contains("raw.githubusercontent.com"))
    }

    func testProcessPipelineWithTabsAndHTML() {
        let input = """
        # Setup Guide

        {% tabs %}
        {% tab title="iOS" %}
        iOS instructions.
        {% endtab %}
        {% tab title="tvOS" %}
        tvOS instructions.
        {% endtab %}
        {% endtabs %}

        <table>
        <tr><th>Feature</th><th>Supported</th></tr>
        <tr><td>Save States</td><td>Yes</td></tr>
        </table>

        <strong>Important:</strong> Read the FAQ.

        <details>
        <summary>Advanced</summary>
        See advanced docs.
        </details>
        """

        let result = GitBookPreprocessor.process(input)

        // No liquid tags remain
        XCTAssertFalse(result.contains("{%"))
        // No HTML tables
        XCTAssertFalse(result.contains("<table>"))
        // No strong tags
        XCTAssertFalse(result.contains("<strong>"))
        // No details/summary tags
        XCTAssertFalse(result.contains("<details>"))
        XCTAssertFalse(result.contains("<summary>"))
        // Content preserved
        XCTAssertTrue(result.contains("### iOS"))
        XCTAssertTrue(result.contains("iOS instructions."))
        XCTAssertTrue(result.contains("Feature"))
        XCTAssertTrue(result.contains("**Important:**"))
        XCTAssertTrue(result.contains("**Advanced**"))
    }
}

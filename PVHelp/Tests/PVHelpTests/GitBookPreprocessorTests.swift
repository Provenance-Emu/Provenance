import XCTest
@testable import PVHelp

final class GitBookPreprocessorTests: XCTestCase {

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
}

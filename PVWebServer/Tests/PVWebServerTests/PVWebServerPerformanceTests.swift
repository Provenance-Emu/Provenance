//
//  PVWebServerPerformanceTests.swift
//  PVWebServerTests
//

import Foundation
import XCTest
@testable import PVWebServer

final class SerialFileWriterTests: XCTestCase {

    func testWriteChunksAndFinalizeReturnsByteCount() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let file = tmp.appendingPathComponent("chunk.bin")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let writer = try SerialFileWriter(destination: file)
        await writer.append(Data(repeating: 0xAB, count: 512))
        await writer.append(Data(repeating: 0xCD, count: 256))
        let total = try await writer.finalize()

        XCTAssertEqual(total, 768)
        let onDisk = try Data(contentsOf: file)
        XCTAssertEqual(onDisk.count, 768)
    }

    func testDoubleFinalizeFails() async throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("double-finalize-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: file) }

        let writer = try SerialFileWriter(destination: file)
        _ = try await writer.finalize()

        do {
            _ = try await writer.finalize()
            XCTFail("Expected second finalize to throw")
        } catch SerialFileWriter.WriterError.alreadyFinalized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class MultipartParsingTests: XCTestCase {

    func testParsesSingleFilePartHeadersAndBodyPrefix() {
        let boundary = "TestBoundary"
        let body = """
        --TestBoundary\r
        Content-Disposition: form-data; name="files[]"; filename="game.rom"\r
        \r
        ROMDATA\r
        --TestBoundary--\r
        """.data(using: .utf8)!

        let parsed = MultipartParsing.parseLeadingPartHeaders(from: body, boundary: boundary)
        XCTAssertEqual(parsed?.filename, "game.rom")
        XCTAssertEqual(parsed?.bodyPrefix, Data("ROMDATA".utf8))
        XCTAssertTrue(parsed?.isComplete ?? false)
    }

    func testBoundaryScannerDetectsClosingMarker() {
        var scanner = MultipartStreamScanner(boundary: "B")
        let chunk = Data("PAYLOAD\r\n--B--".utf8)
        let result = scanner.feed(chunk)
        XCTAssertEqual(result.writeChunk, Data("PAYLOAD".utf8))
        XCTAssertTrue(result.finished)
    }

    func testBoundaryScannerSingleByteFeedsDoNotCrash() {
        let body = Data("HELLO\r\n--WebKitFormBoundary--".utf8)
        var scanner = MultipartStreamScanner(boundary: "WebKitFormBoundary")
        var output = Data()
        var finished = false
        for byte in body {
            let result = scanner.feed(Data([byte]))
            output.append(result.writeChunk)
            finished = result.finished
        }
        XCTAssertEqual(output, Data("HELLO".utf8))
        XCTAssertTrue(finished)
    }

    func testBoundaryScannerSplitChunksReassemblePayload() {
        let payload = Data(repeating: 0x42, count: 4096)
        let boundary = "----ABC"
        let closing = Data("\r\n--\(boundary)--".utf8)
        let body = payload + closing
        var scanner = MultipartStreamScanner(boundary: boundary)
        var output = Data()
        var finished = false
        var offset = 0
        while offset < body.count {
            let end = min(offset + 37, body.count)
            let result = scanner.feed(body[offset..<end])
            output.append(result.writeChunk)
            finished = result.finished
            offset = end
        }
        XCTAssertEqual(output, payload)
        XCTAssertTrue(finished)
    }
}

final class WebDAVPropertyBuilderTests: XCTestCase {

    func testPropfindBlockIncludesFinderFields() {
        let xml = WebDAVPropertyBuilder.propfindResponseBlock(
            href: "Imports/game.zip",
            isDirectory: false,
            size: 1024,
            modified: Date(timeIntervalSince1970: 1_700_000_000),
            created: Date(timeIntervalSince1970: 1_600_000_000)
        )
        XCTAssertTrue(xml.contains("<D:creationdate>"))
        XCTAssertTrue(xml.contains("<D:supportedlock>"))
        XCTAssertTrue(xml.contains("<D:getetag>"))
        XCTAssertTrue(xml.contains("<D:getcontentlength>1024</D:getcontentlength>"))
    }
}

final class WebServerPathSafetyTests: XCTestCase {

    func testResolvedPathBlocksTraversal() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertNotNil(WebServerPathSafety.resolvedPath("Imports/a.zip", withinDirectory: root))
        XCTAssertNil(WebServerPathSafety.resolvedPath("../secret", withinDirectory: root))
    }
}

//
//  SNESHeaderDetectorTests.swift
//  PVHashingTests
//
//  Tests for SNES copier header detection.
//

import Testing
import Foundation
@testable import PVHashing

@Suite("SNES Header Detector Tests")
struct SNESHeaderDetectorTests {

    // MARK: - Header Detection Tests

    @Test("Detect headerless SNES ROM - exact multiple of 1024")
    func testHeaderlessExactMultiple() {
        // Clean ROM: exactly 1MB (1048576 bytes = 1024 * 1024)
        let fileSize: UInt64 = 1024 * 1024
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0, "Clean ROM should have no offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == true)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == false)
    }

    @Test("Detect headered SNES ROM - multiple of 1024 plus 512")
    func testHeaderedROM() {
        // Headered ROM: 1MB + 512 bytes (1049088 bytes = 1024 * 1024 + 512)
        let fileSize: UInt64 = 1024 * 1024 + 512
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 512, "Headered ROM should have 512-byte offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == false)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == true)
    }

    @Test("Detect headerless SNES ROM - 2MB")
    func testHeaderless2MB() {
        // Clean ROM: 2MB (2097152 bytes = 1024 * 2048)
        let fileSize: UInt64 = 2 * 1024 * 1024
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0, "Clean 2MB ROM should have no offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == true)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == false)
    }

    @Test("Detect headered SNES ROM - 2MB plus header")
    func testHeadered2MB() {
        // Headered ROM: 2MB + 512 bytes
        let fileSize: UInt64 = 2 * 1024 * 1024 + 512
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 512, "Headered 2MB ROM should have 512-byte offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == false)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == true)
    }

    @Test("Detect headerless SNES ROM - 4MB")
    func testHeaderless4MB() {
        // Clean ROM: 4MB (common size for larger SNES games)
        let fileSize: UInt64 = 4 * 1024 * 1024
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0, "Clean 4MB ROM should have no offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == true)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == false)
    }

    @Test("Detect headered SNES ROM - 4MB plus header")
    func testHeadered4MB() {
        // Headered ROM: 4MB + 512 bytes
        let fileSize: UInt64 = 4 * 1024 * 1024 + 512
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 512, "Headered 4MB ROM should have 512-byte offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == false)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == true)
    }

    @Test("Handle small file - less than 512 bytes")
    func testSmallFile() {
        // File too small to have a header
        let fileSize: UInt64 = 256
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0, "Small file should default to no offset")
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == false)
    }

    @Test("Handle zero-size file")
    func testZeroSizeFile() {
        let fileSize: UInt64 = 0
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0, "Zero-size file should default to no offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == true)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == false)
    }

    @Test("Handle ambiguous file size - not matching expected patterns")
    func testAmbiguousFileSize() {
        // File size that doesn't match either pattern (e.g., 1024 + 256)
        let fileSize: UInt64 = 1280
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0, "Ambiguous size should default to no offset")
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == false)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == false)
    }

    @Test("Handle file size of exactly 512 bytes")
    func testExactly512Bytes() {
        // Edge case: exactly 512 bytes (just the header, no ROM)
        let fileSize: UInt64 = 512
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0, "Header-only file should default to no offset")
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == false)
    }

    // MARK: - Real-world ROM Size Tests

    @Test("Detect header in typical 512KB game with header")
    func testTypical512KBWithHeader() {
        // 512KB = 524288 bytes, plus 512 = 524800
        let fileSize: UInt64 = 524288 + 512
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 512)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == true)
    }

    @Test("Detect headerless typical 512KB game")
    func testTypical512KBHeaderless() {
        // 512KB = 524288 bytes
        let fileSize: UInt64 = 524288
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 0)
        #expect(SNESHeaderDetector.isHeaderless(fileSize: fileSize) == true)
    }

    @Test("Detect header in typical 768KB game with header")
    func testTypical768KBWithHeader() {
        // 768KB = 786432 bytes, plus 512 = 786944
        let fileSize: UInt64 = 786432 + 512
        let offset = SNESHeaderDetector.detectOffset(fileSize: fileSize)
        #expect(offset == 512)
        #expect(SNESHeaderDetector.hasCopierHeader(fileSize: fileSize) == true)
    }

    // MARK: - File-based Tests

    @Test("Detect offset for non-existent file returns nil")
    func testNonExistentFile() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/file.smc")
        let offset = SNESHeaderDetector.detectOffset(for: nonExistentURL)
        #expect(offset == nil, "Non-existent file should return nil")
    }

    // MARK: - Constants Tests

    @Test("Verify constants are correct")
    func testConstants() {
        #expect(SNESHeaderDetector.copierHeaderSize == 512)
        #expect(SNESHeaderDetector.bankSize == 1024)
    }
}

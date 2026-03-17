//
//  BIOSStatusTests.swift
//  PVPrimitivesTests
//
//  Created by Provenance Emu on 2026-03-17.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVPrimitives

// MARK: - Mock helpers

private struct MockFile: FileInfoProvider {
    var fileName: String
    var md5: String?
    var size: UInt64
    var online: Bool = true
}

private struct MockExpectations: BIOSExpectationsInfoProvider {
    var expectedMD5: String
    var expectedFilename: String
    var expectedSize: Int
    var optional: Bool = true
}

// MARK: - BIOSStatusTests

final class BIOSStatusTests: XCTestCase {

    // MARK: Known MD5 — matches

    func testKnownMD5Match_reports_match() {
        let expectations = MockExpectations(expectedMD5: "AABBCC", expectedFilename: "bios.rom", expectedSize: 0)
        let file = MockFile(fileName: "bios.rom", md5: "aabbcc", size: 0)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        XCTAssertEqual(state, .match)
    }

    // MARK: Known MD5 — mismatch

    func testKnownMD5Mismatch_reports_mismatch() {
        let expectations = MockExpectations(expectedMD5: "AABBCC", expectedFilename: "bios.rom", expectedSize: 0)
        let file = MockFile(fileName: "bios.rom", md5: "112233", size: 0)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        if case .mismatch(let misses) = state {
            XCTAssertTrue(misses.contains(where: { if case .md5 = $0 { return true }; return false }))
        } else {
            XCTFail("Expected mismatch, got \(state)")
        }
    }

    // MARK: Unknown MD5 + unknown size → accept by filename

    func testUnknownMD5_unknownSize_acceptsByFilename() {
        let expectations = MockExpectations(expectedMD5: "", expectedFilename: "bios.rom", expectedSize: 0)
        let file = MockFile(fileName: "bios.rom", md5: nil, size: 0)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        XCTAssertEqual(state, .match)
    }

    // MARK: Unknown MD5 + known size — size matches

    func testUnknownMD5_knownSize_sizeMatches() {
        let expectations = MockExpectations(expectedMD5: "", expectedFilename: "bios.rom", expectedSize: 1024)
        let file = MockFile(fileName: "bios.rom", md5: nil, size: 1024)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        XCTAssertEqual(state, .match)
    }

    // MARK: Unknown MD5 + known size — size mismatch (the key regression test)

    func testUnknownMD5_knownSize_sizeMismatch_reports_mismatch() {
        let expectations = MockExpectations(expectedMD5: "", expectedFilename: "bios.rom", expectedSize: 1024)
        let file = MockFile(fileName: "bios.rom", md5: nil, size: 512)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        if case .mismatch(let misses) = state {
            XCTAssertTrue(misses.contains(where: { if case .size = $0 { return true }; return false }),
                          "Expected a size mismatch entry in \(misses)")
        } else {
            XCTFail("Expected mismatch when unknown MD5 but wrong size; got \(state)")
        }
    }

    // MARK: Known MD5 matches → size check skipped even when size differs

    func testKnownMD5Match_sizeSkipped() {
        let expectations = MockExpectations(expectedMD5: "AABBCC", expectedFilename: "bios.rom", expectedSize: 2048)
        let file = MockFile(fileName: "bios.rom", md5: "aabbcc", size: 1024)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        // A correct MD5 is sufficient — size difference must NOT cause a mismatch.
        XCTAssertEqual(state, .match)
    }

    // MARK: Known MD5 mismatches + size also wrong → both mismatches reported

    func testKnownMD5Mismatch_sizeMismatch_reportsBoth() {
        let expectations = MockExpectations(expectedMD5: "AABBCC", expectedFilename: "bios.rom", expectedSize: 2048)
        let file = MockFile(fileName: "bios.rom", md5: "112233", size: 1024)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        if case .mismatch(let misses) = state {
            let hasMD5 = misses.contains(where: { if case .md5 = $0 { return true }; return false })
            let hasSize = misses.contains(where: { if case .size = $0 { return true }; return false })
            XCTAssertTrue(hasMD5, "Expected MD5 mismatch in \(misses)")
            XCTAssertTrue(hasSize, "Expected size mismatch in \(misses)")
        } else {
            XCTFail("Expected mismatch, got \(state)")
        }
    }

    // MARK: File offline → always missing

    func testOfflineFile_reports_missing() {
        let expectations = MockExpectations(expectedMD5: "", expectedFilename: "bios.rom", expectedSize: 0)
        let file = MockFile(fileName: "bios.rom", md5: nil, size: 0, online: false)
        let state = BIOSStatus.State(expectations: expectations, file: file)
        XCTAssertEqual(state, .missing)
    }
}

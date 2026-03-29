/// TOCParserTests.swift
/// PVOpticalDiscReaderTests
///
/// Unit tests for TOCParser — validates parsing of raw SCSI TOC responses.

import XCTest
@testable import PVOpticalDiscReader

final class TOCParserTests: XCTestCase {

    // MARK: - Happy Path

    func testParseSingleDataTrack() throws {
        // Minimal TOC: 1 data track + lead-out
        // Total bytes = 4 (header) + 8 (track1) + 8 (lead-out) = 20
        // tocLength = 20 - 2 = 18 = 0x0012
        // Track 1: control=0x14 (data), MSF=00:02:00 → LBA=0
        // Lead-out: track=0xAA, MSF=00:47:00 → LBA=3375
        let bytes: [UInt8] = [
            0x00, 0x12,  // TOC data length = 18 (excludes first 2 bytes)
            0x01,        // first track
            0x01,        // last track
            // Track 1 descriptor
            0x00, 0x14, 0x01, 0x00,  // reserved, control(data), trackNum, reserved
            0x00, 0x02, 0x00, 0x00,  // MSF 00:02:00 → LBA 0
            // Lead-out descriptor
            0x00, 0x14, 0xAA, 0x00,  // lead-out (0xAA)
            0x00, 0x2F, 0x00, 0x00   // MSF 00:47:00 → LBA 3375
        ]
        let toc = try XCTUnwrap(TOCParser.parse(bytes, totalSectors: 2100))

        XCTAssertEqual(toc.trackCount, 1)
        XCTAssertFalse(toc.tracks[0].isAudio)
        XCTAssertEqual(toc.tracks[0].trackNumber, 1)
        XCTAssertEqual(toc.tracks[0].startLBA, 0)
        XCTAssertEqual(toc.discType, .dataCD)
    }

    func testParseAudioOnlyDisc() throws {
        // 2 audio tracks + lead-out
        // Total = 4 + 8 + 8 + 8 = 28 bytes; tocLength = 28 - 2 = 26 = 0x001A
        let bytes: [UInt8] = [
            0x00, 0x1A,  // length = 26
            0x01, 0x02,  // first=1, last=2
            // Track 1 (audio): control=0x10
            0x00, 0x10, 0x01, 0x00,
            0x00, 0x02, 0x00, 0x00,  // LBA 0
            // Track 2 (audio)
            0x00, 0x10, 0x02, 0x00,
            0x00, 0x10, 0x00, 0x00,  // LBA ~450
            // Lead-out
            0x00, 0x10, 0xAA, 0x00,
            0x00, 0x3C, 0x00, 0x00   // LBA ~2400
        ]
        let toc = try XCTUnwrap(TOCParser.parse(bytes, totalSectors: 2400))

        XCTAssertEqual(toc.trackCount, 2)
        XCTAssertTrue(toc.tracks[0].isAudio)
        XCTAssertTrue(toc.tracks[1].isAudio)
        XCTAssertEqual(toc.discType, .audioCD)
    }

    func testParseMixedModeDisc() throws {
        // PSX-style: track 1 = data, tracks 2+ = audio
        // Total = 4 + 8 + 8 + 8 = 28; tocLength = 26 = 0x001A
        let bytes: [UInt8] = [
            0x00, 0x1A,
            0x01, 0x02,
            // Track 1: data (control=0x14)
            0x00, 0x14, 0x01, 0x00,
            0x00, 0x02, 0x00, 0x00,
            // Track 2: audio (control=0x10)
            0x00, 0x10, 0x02, 0x00,
            0x00, 0x28, 0x00, 0x00,
            // Lead-out
            0x00, 0x10, 0xAA, 0x00,
            0x00, 0x50, 0x00, 0x00
        ]
        let toc = try XCTUnwrap(TOCParser.parse(bytes, totalSectors: 3000))

        XCTAssertEqual(toc.trackCount, 2)
        XCTAssertFalse(toc.tracks[0].isAudio)  // track 1 = data
        XCTAssertTrue(toc.tracks[1].isAudio)   // track 2 = audio
        XCTAssertEqual(toc.discType, .mixedMode)
    }

    // MARK: - Edge Cases

    func testReturnsNilForEmptyData() {
        XCTAssertNil(TOCParser.parse([], totalSectors: 0))
    }

    func testReturnsNilForTruncatedHeader() {
        XCTAssertNil(TOCParser.parse([0x00, 0x10, 0x01], totalSectors: 100))
    }

    func testSectorCountCalculation() throws {
        // Track 1 starts at LBA 0 (MSF 00:02:00), Track 2 starts at LBA 450 (MSF 00:08:00)
        // Lead-out at MSF 00:34:00 → LBA = (34×75) - 150 = 2550 - 150 = 2400
        // Expected: track 1 = 450 sectors, track 2 = 1950 sectors
        // Total = 4 + 8 + 8 + 8 = 28; tocLength = 26 = 0x001A
        let bytes: [UInt8] = [
            0x00, 0x1A,
            0x01, 0x02,
            0x00, 0x14, 0x01, 0x00,
            0x00, 0x02, 0x00, 0x00,  // MSF 00:02:00 → LBA 0
            0x00, 0x14, 0x02, 0x00,
            0x00, 0x08, 0x00, 0x00,  // MSF 00:08:00 → LBA 450
            0x00, 0x14, 0xAA, 0x00,
            0x00, 0x22, 0x00, 0x00   // MSF 00:34:00 → LBA 2400
        ]
        let toc = try XCTUnwrap(TOCParser.parse(bytes, totalSectors: 2400))

        XCTAssertEqual(toc.tracks[0].sectorCount, 450)
        XCTAssertEqual(toc.tracks[1].sectorCount, 1950)
    }
}

// MARK: - MSFAddress Tests

final class MSFAddressTests: XCTestCase {

    func testMSFToLBAZero() {
        // 00:02:00 = (0×60 + 2)×75 + 0 - 150 = 150 - 150 = 0
        let msf = MSFAddress(minutes: 0, seconds: 2, frames: 0)
        XCTAssertEqual(msf.lba, 0)
    }

    func testMSFToLBANonZero() {
        // 00:08:00 = (0×60 + 8)×75 + 0 - 150 = 600 - 150 = 450
        let msf = MSFAddress(minutes: 0, seconds: 8, frames: 0)
        XCTAssertEqual(msf.lba, 450)
    }

    func testMSFDescription() {
        let msf = MSFAddress(minutes: 1, seconds: 23, frames: 45)
        XCTAssertEqual(msf.description, "01:23:45")
    }
}

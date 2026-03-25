//
//  PatchFormatTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class PatchFormatTests: XCTestCase {

    func testDetectIPS() {
        let url = URL(fileURLWithPath: "/roms/patch.ips")
        XCTAssertEqual(PatchFormat.detect(from: url), .ips)
    }

    func testDetectIPS32() {
        let url = URL(fileURLWithPath: "/roms/patch.ips32")
        XCTAssertEqual(PatchFormat.detect(from: url), .ips32)
    }

    func testIPS32HasNoIntegrityCheck() {
        XCTAssertFalse(PatchFormat.ips32.hasIntegrityCheck)
    }

    func testDetectBPS() {
        let url = URL(fileURLWithPath: "/roms/translation.bps")
        XCTAssertEqual(PatchFormat.detect(from: url), .bps)
    }

    func testDetectUPS() {
        let url = URL(fileURLWithPath: "/roms/fix.ups")
        XCTAssertEqual(PatchFormat.detect(from: url), .ups)
    }

    func testDetectXDelta() {
        let url = URL(fileURLWithPath: "/roms/patch.xdelta")
        XCTAssertEqual(PatchFormat.detect(from: url), .xdelta)
    }

    func testDetectXDelta3() {
        let url = URL(fileURLWithPath: "/roms/patch.xdelta3")
        XCTAssertEqual(PatchFormat.detect(from: url), .xdelta3)
    }

    func testDetectDeltaAsXDelta() {
        let url = URL(fileURLWithPath: "/roms/patch.delta")
        XCTAssertEqual(PatchFormat.detect(from: url), .xdelta)
    }

    func testDetectUnknownReturnsNil() {
        let url = URL(fileURLWithPath: "/roms/game.sfc")
        XCTAssertNil(PatchFormat.detect(from: url))
    }

    func testDetectNSP() {
        let url = URL(fileURLWithPath: "/roms/patch.nsp")
        XCTAssertEqual(PatchFormat.detect(from: url), .nsp)
    }

    func testDetectCaseInsensitive() {
        let url = URL(fileURLWithPath: "/roms/patch.IPS")
        XCTAssertEqual(PatchFormat.detect(from: url), .ips)
    }

    func testAllFileExtensionsNotEmpty() {
        XCTAssertFalse(PatchFormat.allFileExtensions.isEmpty)
    }

    func testIPSHasNoIntegrityCheck() {
        XCTAssertFalse(PatchFormat.ips.hasIntegrityCheck)
    }

    func testBPSHasIntegrityCheck() {
        XCTAssertTrue(PatchFormat.bps.hasIntegrityCheck)
    }

    func testUPSHasIntegrityCheck() {
        XCTAssertTrue(PatchFormat.ups.hasIntegrityCheck)
    }
}

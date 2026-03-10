//
//  PatchEntryTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class PatchEntryTests: XCTestCase {

    func testDisplayTitleUsesMetadataTitle() {
        var entry = PatchEntry(
            patchFileURL: URL(fileURLWithPath: "/patches/smb_translation.ips"),
            format: .ips
        )
        entry.metadata.title = "Super Mario Bros. — English Translation"
        XCTAssertEqual(entry.displayTitle, "Super Mario Bros. — English Translation")
    }

    func testDisplayTitleFallsBackToFilename() {
        let entry = PatchEntry(
            patchFileURL: URL(fileURLWithPath: "/patches/smb_translation.ips"),
            format: .ips
        )
        XCTAssertEqual(entry.displayTitle, "smb_translation")
    }

    func testDefaultValues() {
        let entry = PatchEntry(
            patchFileURL: URL(fileURLWithPath: "/patches/test.ips"),
            format: .ips
        )
        XCTAssertNil(entry.baseGameIdentifier)
        XCTAssertFalse(entry.hasBeenApplied)
        XCTAssertEqual(entry.metadata.categories, [])
    }

    func testCodableRoundTrip() throws {
        let original = PatchEntry(
            patchFileURL: URL(fileURLWithPath: "/patches/test.bps"),
            format: .bps,
            baseGameIdentifier: "abc123",
            metadata: PatchMetadata(title: "Test Patch", author: "Tester")
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PatchEntry.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

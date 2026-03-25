//
//  PatchApplierTests.swift
//  PVPatchingTests
//

import Foundation
import XCTest
@testable import PVPatching

/// Verifies `PatchApplier` behavior for format-routing and unsupported formats.
final class PatchApplierTests: XCTestCase {
    /// Ensures `.nsp` is detected, routed, and reported as unsupported until implemented.
    func testApplyNSPThrowsUnsupportedFormat() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchApplierTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let romURL = tempDirectory.appendingPathComponent("game.rom")
        let nspPatchURL = tempDirectory.appendingPathComponent("patch.nsp")

        try Data([0x00]).write(to: romURL)
        try Data([0x4E, 0x53, 0x50]).write(to: nspPatchURL)

        let applier = PatchApplier()

        do {
            _ = try await applier.apply(patchURL: nspPatchURL, to: romURL)
            XCTFail("Expected NSP patch application to throw unsupportedFormat")
        } catch let error as PatchError {
            guard case .unsupportedFormat(let reason) = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
            XCTAssertTrue(reason.contains("NSP"), "Expected error reason to mention NSP, got: \(reason)")
        }
    }
}

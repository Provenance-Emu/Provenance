//
//  UPSPatcherTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class UPSPatcherTests: XCTestCase {

    private let patcher = UPSPatcher()

    // MARK: - Minimum size guard

    func testEmptyPatchThrows() {
        XCTAssertThrowsError(try patcher.apply(patch: Data(), to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testTooSmallPatchThrows() {
        // 17 bytes: valid header + 13 trailing bytes — below the 18-byte minimum.
        // Without the fix this would crash on readLE32(patch, at: patch.count - 12).
        var data = Data("UPS1".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 13))
        XCTAssertEqual(data.count, 17)
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testBadHeaderThrows() {
        var data = Data("XUPS".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 20))
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }
}

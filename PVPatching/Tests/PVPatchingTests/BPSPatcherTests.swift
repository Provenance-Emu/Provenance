//
//  BPSPatcherTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class BPSPatcherTests: XCTestCase {

    private let patcher = BPSPatcher()

    // MARK: - Minimum size guard

    func testEmptyPatchThrows() {
        XCTAssertThrowsError(try patcher.apply(patch: Data(), to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testTooSmallPatchThrows() {
        // 18 bytes: valid header + 14 trailing bytes — below the 19-byte minimum.
        // Without the fix this would crash on readLE32(patch, at: patch.count - 12).
        var data = Data("BPS1".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 14))
        XCTAssertEqual(data.count, 18)
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testBadHeaderThrows() {
        var data = Data("XBPS".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 20))
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }
}

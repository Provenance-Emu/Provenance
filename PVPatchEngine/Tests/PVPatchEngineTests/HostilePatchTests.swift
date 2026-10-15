//
//  HostilePatchTests.swift
//  PVPatchEngineTests
//
//  Patches crafted to overflow the arithmetic on values they carry. Each must be refused with a
//  PatchError: a trap would take the app down, and inspect runs on the main thread.
//

import XCTest
@testable import PVPatchEngine

final class HostilePatchTests: PatchTestCase {
    private let halfMax = UInt64(Int64.max / 2)

    // MARK: - Builders

    private func bps(sourceSize: UInt64, targetSize: UInt64, actions: [UInt8]) -> [UInt8] {
        let body = Array("BPS1".utf8) + variableLength(sourceSize) + variableLength(targetSize) + variableLength(0)
            + actions + littleEndian(0) + littleEndian(0)
        return appendingPatchCRC(body)
    }

    private func bpsAction(_ command: UInt64, length: UInt64 = 1) -> [UInt8] {
        variableLength((length - 1) << 2 | command)
    }

    private func bpsSourceCopy(delta: UInt64, negative: Bool = false) -> [UInt8] {
        bpsAction(2) + variableLength(delta << 1 | (negative ? 1 : 0))
    }

    private func ups(inputSize: UInt64, outputSize: UInt64, hunks: [UInt8]) -> [UInt8] {
        let body = Array("UPS1".utf8) + variableLength(inputSize) + variableLength(outputSize) + hunks + littleEndian(0) + littleEndian(0)
        return appendingPatchCRC(body)
    }

    /// RFC 3284 base-128 integer, most significant group first.
    private func vcdiffInteger(_ value: UInt64) -> [UInt8] {
        var groups: [UInt8] = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            groups.append(UInt8(rest & 0x7F) | 0x80)
            rest >>= 7
        }
        return groups.reversed()
    }

    /// One VCDIFF window that copies `sourceSize` bytes of source from `sourcePosition`, with an empty instruction stream.
    private func vcdiffSourceWindow(sourcePosition: UInt64, sourceSize: UInt64, targetLength: UInt64) -> [UInt8] {
        let delta = vcdiffInteger(targetLength) + [0x00] + vcdiffInteger(0) + vcdiffInteger(0) + vcdiffInteger(0)
        return [0xD6, 0xC3, 0xC4, 0x00, 0x00, 0x01] + vcdiffInteger(sourceSize) + vcdiffInteger(sourcePosition)
            + vcdiffInteger(UInt64(delta.count)) + delta
    }

    private func vcdiff(windowTargetLengths: [UInt64]) -> [UInt8] {
        var bytes: [UInt8] = [0xD6, 0xC3, 0xC4, 0x00, 0x00]
        for length in windowTargetLengths {
            let delta = vcdiffInteger(length)
            bytes += [0x00] + vcdiffInteger(UInt64(delta.count)) + delta
        }
        return bytes
    }

    private func applyIgnoringSource(_ patch: [UInt8], ext: String) async -> PatchError? {
        await expectPatchError {
            _ = try await apply(patch, ext: ext, to: [1, 2, 3, 4], options: PatchOptions(ignoreSourceChecksum: true))
        }
    }

    private func assertCorrupt(_ error: PatchError?, file: StaticString = #filePath, line: UInt = #line) {
        guard case .corruptPatch? = error else { return XCTFail("got \(String(describing: error))", file: file, line: line) }
    }

    // MARK: - BPS

    func testBPSSourceOffsetThatWrapsIsCorrupt() async {
        let actions = bpsSourceCopy(delta: halfMax) + bpsSourceCopy(delta: halfMax)
        assertCorrupt(await applyIgnoringSource(bps(sourceSize: .max, targetSize: 2, actions: actions), ext: "bps"))
    }

    func testBPSSourceOffsetPastTheSourceIsCorrupt() async {
        assertCorrupt(await applyIgnoringSource(bps(sourceSize: 4, targetSize: 1, actions: bpsSourceCopy(delta: 100)), ext: "bps"))
    }

    func testBPSSourceCopyRunningPastTheSourceIsCorrupt() async {
        let actions = bpsAction(2, length: 3) + variableLength(3 << 1)
        assertCorrupt(await applyIgnoringSource(bps(sourceSize: 4, targetSize: 3, actions: actions), ext: "bps"))
    }

    func testBPSNegativeOffsetIsCorrupt() async {
        assertCorrupt(await applyIgnoringSource(bps(sourceSize: 4, targetSize: 1, actions: bpsSourceCopy(delta: 1, negative: true)), ext: "bps"))
    }

    func testBPSOffsetNeverReadIsRejected() async {
        let error = await applyIgnoringSource(bps(sourceSize: 4, targetSize: 1, actions: bpsAction(3) + variableLength(halfMax << 1)), ext: "bps")
        assertCorrupt(error)
    }

    // MARK: - UPS

    func testUPSHunkOffsetBeyondTheImageIsCorrupt() async {
        assertCorrupt(await applyIgnoringSource(ups(inputSize: 4, outputSize: 4, hunks: variableLength(5) + [1, 0]), ext: "ups"))
    }

    func testUPSHunkOffsetNearTheLimitOfUInt64IsCorrupt() async {
        for skip in [UInt64.max - 1, UInt64.max / 2, UInt64(Int64.max)] {
            assertCorrupt(await applyIgnoringSource(ups(inputSize: 4, outputSize: 4, hunks: variableLength(skip) + [1, 0]), ext: "ups"))
        }
    }

    func testUPSHunkRunningPastTheImageIsCorrupt() async {
        assertCorrupt(await applyIgnoringSource(ups(inputSize: 4, outputSize: 4, hunks: variableLength(2) + [1, 1, 1, 1, 0]), ext: "ups"))
    }

    func testUPSHunkBeyondTheShorterImageStillApplies() async throws {
        let (_, output) = try await apply(UPSBuilder.patch(source: [1, 2, 3, 4], target: [1, 2]), ext: "ups", to: [1, 2, 3, 4])
        XCTAssertEqual(output, [1, 2])
    }

    // MARK: - xdelta3

    func testVCDIFFWindowSizesThatWrapAreCorrupt() throws {
        let patch = try write(vcdiff(windowTargetLengths: [1 << 63, 1 << 63]), named: "wrap.xdelta")
        XCTAssertThrowsError(try PatchEngine.inspect(patch: patch)) { error in
            assertCorrupt(error as? PatchError)
        }
    }

    func testVCDIFFWindowLargerThanTheDecoderLimitIsCorrupt() throws {
        let patch = try write(vcdiff(windowTargetLengths: [XDelta3Applier.maxTargetWindow + 1]), named: "big.xdelta")
        XCTAssertThrowsError(try PatchEngine.inspect(patch: patch)) { error in
            assertCorrupt(error as? PatchError)
        }
    }

    func testVCDIFFSourceSegmentPastTheSourceIsAnErrorNotACrash() async {
        for position in [UInt64(1 << 40), UInt64(1) << 63, UInt64.max - 1] {
            let patch = vcdiffSourceWindow(sourcePosition: position, sourceSize: 1, targetLength: 1)
            for ignoreSource in [false, true] {
                let error = await expectPatchError {
                    _ = try await apply(patch, ext: "xdelta", to: [1, 2, 3, 4], options: PatchOptions(ignoreSourceChecksum: ignoreSource))
                }
                XCTAssertNotNil(error, "position \(position), ignoreSource \(ignoreSource)")
            }
        }
    }

    func testVCDIFFSourceSegmentWrappingTheOffsetIsCorrupt() async {
        let patch = vcdiffSourceWindow(sourcePosition: UInt64.max, sourceSize: 2, targetLength: 1)
        assertCorrupt(await applyIgnoringSource(patch, ext: "xdelta"))
    }

    func testVCDIFFWindowsWithinTheLimitSumUp() throws {
        let patch = try write(vcdiff(windowTargetLengths: [10, 20]), named: "ok.xdelta")
        XCTAssertEqual(try PatchEngine.inspect(patch: patch).targetSize, 30)
    }
}

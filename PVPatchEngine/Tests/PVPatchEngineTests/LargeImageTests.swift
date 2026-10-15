//
//  LargeImageTests.swift
//  PVPatchEngineTests
//
//  Patches sparse images larger than 4 GiB and checks that resident memory stays small.
//  The images are sparse, so the source costs no disk; the output does (about 4.5 GB at a time).
//

import Darwin
import XCTest
@testable import PVPatchEngine

/// Samples the process's resident size while a patch runs.
private final class ResidentSampler: @unchecked Sendable {
    private let lock = NSLock()
    private var peakBytes: UInt64 = 0
    private var running = true

    static func currentResidentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }

    func start() {
        record()
        Thread.detachNewThread { [self] in
            while isRunning {
                record()
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
    }

    private var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    private func record() {
        let current = Self.currentResidentBytes()
        lock.lock()
        peakBytes = max(peakBytes, current)
        lock.unlock()
    }

    func stop() -> UInt64 {
        record()
        lock.lock()
        running = false
        defer { lock.unlock() }
        return peakBytes
    }
}

final class LargeImageTests: PatchTestCase {
    private static let sourceSize: UInt64 = 4_500_000_000
    private static let freeSpaceNeeded: Int64 = 20_000_000_000
    private static let residentLimit: UInt64 = 200 << 20
    private static let growthLimit: UInt64 = 64 << 20

    private func requireFreeSpace() throws {
        let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        try XCTSkipIf(free < Self.freeSpaceNeeded, "needs \(Self.freeSpaceNeeded / 1_000_000_000) GB free, have \(free / 1_000_000_000) GB")
    }

    private func makeSparseSource() throws -> URL {
        let url = directory.appendingPathComponent("source.bin")
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: Self.sourceSize)
        try handle.close()
        return url
    }

    private func zeroCRC(continuing crc: UInt32 = 0, count: UInt64) -> UInt32 {
        let zeros = [UInt8](repeating: 0, count: 4 << 20)
        var value = crc
        var left = count
        while left > 0 {
            let chunk = Int(min(left, UInt64(zeros.count)))
            value = zeros.withUnsafeBytes { Checksums.crc32(value, $0.baseAddress!, count: chunk) }
            left -= UInt64(chunk)
        }
        return value
    }

    private func bytes(of url: URL, at offset: UInt64, count: Int) throws -> [UInt8] {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        return [UInt8](try handle.read(upToCount: count) ?? Data())
    }

    private func fileSize(_ url: URL) throws -> UInt64 {
        UInt64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
    }

    private func expectBoundedMemory(peak: UInt64, baseline: UInt64, _ label: String) {
        print("\(label): resident size \(baseline >> 20) MiB before, peak \(peak >> 20) MiB")
        XCTAssertLessThan(peak, Self.residentLimit, "\(label) used \(peak >> 20) MiB resident")
        XCTAssertLessThan(peak - min(peak, baseline), Self.growthLimit, "\(label) grew by more than \(Self.growthLimit >> 20) MiB")
    }

    func testBPSPastFourGiBStreamsWithBoundedMemory() async throws {
        try requireFreeSpace()
        let sourceURL = try makeSparseSource()
        let lead: UInt64 = 4_300_000_000
        let copied: UInt64 = 100_000
        let marker = Array("PAST-4GiB-marker-0123456789abcd".utf8)
        let targetSize = lead + UInt64(marker.count) + copied + UInt64(marker.count)

        var body = Array("BPS1".utf8) + variableLength(Self.sourceSize) + variableLength(targetSize) + variableLength(0)
        body += variableLength((lead - 1) << 2 | 0)
        body += variableLength(UInt64(marker.count - 1) << 2 | 1) + marker
        body += variableLength((copied - 1) << 2 | 2) + variableLength(4_400_000_000 << 1)
        body += variableLength(UInt64(marker.count - 1) << 2 | 3) + variableLength(lead << 1)
        var targetCRC = zeroCRC(count: lead)
        targetCRC = marker.withUnsafeBytes { Checksums.crc32(targetCRC, $0.baseAddress!, count: $0.count) }
        targetCRC = zeroCRC(continuing: targetCRC, count: copied)
        targetCRC = marker.withUnsafeBytes { Checksums.crc32(targetCRC, $0.baseAddress!, count: $0.count) }
        body += littleEndian(zeroCRC(count: Self.sourceSize)) + littleEndian(targetCRC)
        let patchURL = try write(appendingPatchCRC(body), named: "big.bps")
        let outputURL = directory.appendingPathComponent("output.bin")

        let baseline = ResidentSampler.currentResidentBytes()
        let sampler = ResidentSampler()
        sampler.start()
        let result: PatchResult
        do {
            result = try await PatchEngine.apply(patch: patchURL, source: sourceURL, output: outputURL)
        } catch {
            _ = sampler.stop()
            throw error
        }
        expectBoundedMemory(peak: sampler.stop(), baseline: baseline, "BPS 4.5 GB")

        XCTAssertEqual(result.bytesWritten, targetSize)
        XCTAssertEqual(try fileSize(outputURL), targetSize)
        XCTAssertTrue(result.verifiedChecksums.contains(.targetCRC32(targetCRC)))
        XCTAssertTrue(result.verifiedChecksums.contains(.sourceCRC32(zeroCRC(count: Self.sourceSize))))
        XCTAssertEqual(try bytes(of: outputURL, at: lead - 4, count: 4 + marker.count), [0, 0, 0, 0] + marker)
        XCTAssertEqual(try bytes(of: outputURL, at: targetSize - UInt64(marker.count), count: marker.count), marker)
        XCTAssertEqual(try bytes(of: outputURL, at: lead + UInt64(marker.count), count: 8), [UInt8](repeating: 0, count: 8))
        XCTAssertEqual(try bytes(of: outputURL, at: (1 << 32) - 2, count: 4), [0, 0, 0, 0])
    }

    func testPPFRecordPastFourGiBStreamsWithBoundedMemory() async throws {
        try requireFreeSpace()
        let sourceURL = try makeSparseSource()
        let offset: UInt64 = 4_400_000_000
        let payload = Array("record past 4 GiB".utf8)
        let patchURL = try write(PPFBuilder.v3(block: nil, records: [(offset, payload)]), named: "big.ppf")
        let outputURL = directory.appendingPathComponent("output.bin")

        let baseline = ResidentSampler.currentResidentBytes()
        let sampler = ResidentSampler()
        sampler.start()
        let result: PatchResult
        do {
            result = try await PatchEngine.apply(patch: patchURL, source: sourceURL, output: outputURL)
        } catch {
            _ = sampler.stop()
            throw error
        }
        expectBoundedMemory(peak: sampler.stop(), baseline: baseline, "PPF 4.5 GB")

        XCTAssertEqual(result.bytesWritten, Self.sourceSize)
        XCTAssertEqual(try fileSize(outputURL), Self.sourceSize)
        XCTAssertEqual(try bytes(of: outputURL, at: offset, count: payload.count), payload)
        XCTAssertEqual(try bytes(of: outputURL, at: offset - 8, count: 8), [UInt8](repeating: 0, count: 8))
        XCTAssertEqual(try bytes(of: outputURL, at: offset + UInt64(payload.count), count: 8), [UInt8](repeating: 0, count: 8))
    }

    func testIPS32GrowsAnImagePastTheEndOfASparseSource() async throws {
        try requireFreeSpace()
        let sourceURL = try makeSparseSource()
        let offset: UInt64 = 4_294_000_000
        let patch = IPSBuilder.patch(records: [(offset, [UInt8](repeating: 0x5A, count: 5_000))], ips32: true)
        let patchURL = try write(patch, named: "big.ips32")
        let outputURL = directory.appendingPathComponent("output.bin")
        let baseline = ResidentSampler.currentResidentBytes()
        let sampler = ResidentSampler()
        sampler.start()
        let result: PatchResult
        do {
            result = try await PatchEngine.apply(patch: patchURL, source: sourceURL, output: outputURL)
        } catch {
            _ = sampler.stop()
            throw error
        }
        expectBoundedMemory(peak: sampler.stop(), baseline: baseline, "IPS32 4.5 GB")
        XCTAssertEqual(result.bytesWritten, Self.sourceSize)
        XCTAssertEqual(try bytes(of: outputURL, at: offset + 4_900, count: 8), [UInt8](repeating: 0x5A, count: 8))
        XCTAssertEqual(try bytes(of: outputURL, at: offset + 5_000, count: 4), [0, 0, 0, 0])
    }

    /// RFC 3284 integer: base 128, most significant group first.
    private func vcdiffInteger(_ value: UInt64) -> [UInt8] {
        var groups = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            groups.append(UInt8(rest & 0x7F) | 0x80)
            rest >>= 7
        }
        return groups.reversed()
    }

    func testXDelta3CopiesFromASourceOffsetAboveFourGiB() async throws {
        let sourceURL = try makeSparseSource()
        // 32 bytes before a 128 KiB source-block boundary, so the copy spans two blocks above 4 GiB.
        let position: UInt64 = 33_570 * 131_072 - 32
        let payload = (0..<64).map { UInt8(0xA0 &+ $0) }
        let handle = try FileHandle(forWritingTo: sourceURL)
        try handle.seek(toOffset: position)
        try handle.write(contentsOf: Data(payload))
        try handle.close()

        // One window: VCD_SOURCE, segment of 64 bytes at `position`, a single COPY of 64 bytes from address 0.
        let delta: [UInt8] = [0x40, 0x00, 0x00, 0x02, 0x01, 0x13, 0x40, 0x00]
        let patch: [UInt8] = [0xD6, 0xC3, 0xC4, 0x00, 0x00, 0x01] + vcdiffInteger(64) + vcdiffInteger(position)
            + vcdiffInteger(UInt64(delta.count)) + delta
        let patchURL = try write(patch, named: "big.xdelta")
        let outputURL = directory.appendingPathComponent("output.bin")

        let info = try PatchEngine.inspect(patch: patchURL)
        XCTAssertEqual(info.targetSize, 64)
        XCTAssertEqual(info.minimumSourceSize, position + 64)

        let result = try await PatchEngine.apply(patch: patchURL, source: sourceURL, output: outputURL)
        XCTAssertEqual(result.bytesWritten, 64)
        XCTAssertEqual(try read(outputURL), payload)
    }
}

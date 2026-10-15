//
//  TestSupport.swift
//  PVPatchEngineTests
//
//  Temporary files, patch builders for every format, and error-matching helpers.
//

import Foundation
import XCTest
@testable import PVPatchEngine

class PatchTestCase: XCTestCase {
    private(set) var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PVPatchEngineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    @discardableResult
    func write(_ bytes: [UInt8], named name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }

    func read(_ url: URL) throws -> [UInt8] {
        [UInt8](try Data(contentsOf: url))
    }

    var partialFiles: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0.hasSuffix(".partial") }
    }

    /// Applies `patch` (written as `patch.<ext>`) to `source` and returns the result and the output bytes.
    func apply(
        _ patch: [UInt8],
        ext: String,
        to source: [UInt8],
        options: PatchOptions = PatchOptions()
    ) async throws -> (result: PatchResult, output: [UInt8]) {
        let patchURL = try write(patch, named: "patch.\(ext)")
        let sourceURL = try write(source, named: "source.bin")
        let outputURL = directory.appendingPathComponent("output.bin")
        let result = try await PatchEngine.apply(patch: patchURL, source: sourceURL, output: outputURL, options: options)
        return (result, try read(outputURL))
    }

    /// Runs `body`, expecting a `PatchError`, and returns it. Fails the test otherwise.
    func expectPatchError(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async -> PatchError? {
        do {
            try await body()
            XCTFail("expected a PatchError but nothing was thrown", file: file, line: line)
        } catch let error as PatchError {
            return error
        } catch {
            XCTFail("expected a PatchError but got \(error)", file: file, line: line)
        }
        return nil
    }
}

func crc32(_ bytes: [UInt8]) -> UInt32 {
    bytes.withUnsafeBytes { Checksums.crc32(0, $0.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!, count: $0.count) }
}

func littleEndian(_ value: UInt32) -> [UInt8] {
    (0..<4).map { UInt8(truncatingIfNeeded: value >> UInt32(8 * $0)) }
}

func littleEndian(_ value: UInt64, width: Int) -> [UInt8] {
    (0..<width).map { UInt8(truncatingIfNeeded: value >> UInt64(8 * $0)) }
}

func bigEndian(_ value: UInt64, width: Int) -> [UInt8] {
    (0..<width).map { UInt8(truncatingIfNeeded: value >> UInt64(8 * (width - 1 - $0))) }
}

/// BPS / UPS variable-length number.
func variableLength(_ number: UInt64) -> [UInt8] {
    var bytes: [UInt8] = []
    var value = number
    while true {
        let low = UInt8(value & 0x7F)
        value >>= 7
        if value == 0 {
            bytes.append(0x80 | low)
            return bytes
        }
        bytes.append(low)
        value -= 1
    }
}

/// The CRC32 stored in the last four bytes of a BPS or UPS patch.
func trailingCRC(_ patch: [UInt8]) -> UInt32 {
    patch.suffix(4).enumerated().reduce(0) { $0 | UInt32($1.element) << UInt32(8 * $1.offset) }
}

/// Appends the CRC32 of everything so far, the way BPS and UPS close their patches.
func appendingPatchCRC(_ body: [UInt8]) -> [UInt8] {
    body + littleEndian(crc32(body))
}

// MARK: - IPS

enum IPSBuilder {
    static func patch(
        records: [(offset: UInt64, data: [UInt8])] = [],
        runs: [(offset: UInt64, count: Int, value: UInt8)] = [],
        ips32: Bool = false,
        truncateTo: UInt64? = nil
    ) -> [UInt8] {
        let width = ips32 ? 4 : 3
        var bytes = Array((ips32 ? "IPS32" : "PATCH").utf8)
        for record in records {
            bytes += bigEndian(record.offset, width: width) + bigEndian(UInt64(record.data.count), width: 2) + record.data
        }
        for run in runs {
            bytes += bigEndian(run.offset, width: width) + [0, 0] + bigEndian(UInt64(run.count), width: 2) + [run.value]
        }
        bytes += Array((ips32 ? "EEOF" : "EOF").utf8)
        if let truncateTo, !ips32 { bytes += bigEndian(truncateTo, width: 3) }
        return bytes
    }
}

// MARK: - BPS

/// Builds a BPS patch and, alongside it, the target a straightforward in-memory decoder would produce.
struct BPSBuilder {
    private(set) var actions: [UInt8] = []
    private(set) var target: [UInt8] = []
    private var sourceRelative: Int64 = 0
    private var targetRelative: Int64 = 0
    let source: [UInt8]
    var metadata: [UInt8] = []

    init(source: [UInt8]) {
        self.source = source
    }

    private mutating func header(_ command: UInt64, length: Int) {
        actions += variableLength(UInt64(length - 1) << 2 | command)
    }

    private func signed(_ delta: Int64) -> [UInt8] {
        variableLength(UInt64(abs(delta)) << 1 | (delta < 0 ? 1 : 0))
    }

    mutating func sourceRead(_ length: Int) {
        header(0, length: length)
        for _ in 0..<length {
            let position = target.count
            target.append(position < source.count ? source[position] : 0)
        }
    }

    mutating func targetRead(_ bytes: [UInt8]) {
        header(1, length: bytes.count)
        actions += bytes
        target += bytes
    }

    mutating func sourceCopy(offset: Int, length: Int) {
        header(2, length: length)
        actions += signed(Int64(offset) - sourceRelative)
        sourceRelative = Int64(offset)
        for _ in 0..<length {
            target.append(sourceRelative < source.count ? source[Int(sourceRelative)] : 0)
            sourceRelative += 1
        }
    }

    mutating func targetCopy(offset: Int, length: Int) {
        header(3, length: length)
        actions += signed(Int64(offset) - targetRelative)
        targetRelative = Int64(offset)
        for _ in 0..<length {
            target.append(target[Int(targetRelative)])
            targetRelative += 1
        }
    }

    /// The patch file for the actions added so far. `targetCRC` can be overridden to build a bad patch.
    func patch(sourceCRC: UInt32? = nil, targetCRC: UInt32? = nil) -> [UInt8] {
        var bytes = Array("BPS1".utf8)
        bytes += variableLength(UInt64(source.count)) + variableLength(UInt64(target.count))
        bytes += variableLength(UInt64(metadata.count)) + metadata + actions
        bytes += littleEndian(sourceCRC ?? crc32(source)) + littleEndian(targetCRC ?? crc32(target))
        return appendingPatchCRC(bytes)
    }
}

// MARK: - UPS

enum UPSBuilder {
    /// A UPS patch from `source` to `target`; it also applies in reverse.
    static func patch(source: [UInt8], target: [UInt8]) -> [UInt8] {
        var bytes = Array("UPS1".utf8) + variableLength(UInt64(source.count)) + variableLength(UInt64(target.count))
        let length = max(source.count, target.count)
        func xor(_ index: Int) -> UInt8 {
            (index < source.count ? source[index] : 0) ^ (index < target.count ? target[index] : 0)
        }
        var cursor = 0
        var index = 0
        while index < length {
            guard xor(index) != 0 else {
                index += 1
                continue
            }
            bytes += variableLength(UInt64(index - cursor))
            while index < length, xor(index) != 0 {
                bytes.append(xor(index))
                index += 1
            }
            bytes.append(0)
            index += 1
            cursor = index
        }
        bytes += littleEndian(crc32(source)) + littleEndian(crc32(target))
        return appendingPatchCRC(bytes)
    }
}

// MARK: - PPF

enum PPFBuilder {
    private static func header(version: Int) -> [UInt8] {
        var bytes = Array("PPF\(version)0".utf8) + [UInt8(version - 1)]
        bytes += Array("test patch".utf8.prefix(50))
        bytes += [UInt8](repeating: 0x20, count: 50 - min(50, "test patch".utf8.count))
        return bytes
    }

    static func v1(records: [(offset: UInt64, data: [UInt8])]) -> [UInt8] {
        header(version: 1) + records.flatMap { littleEndian($0.offset, width: 4) + [UInt8($0.data.count)] + $0.data }
    }

    static func v2(sourceSize: UInt32, block: [UInt8], records: [(offset: UInt64, data: [UInt8])]) -> [UInt8] {
        header(version: 2) + littleEndian(sourceSize) + block
            + records.flatMap { littleEndian($0.offset, width: 4) + [UInt8($0.data.count)] + $0.data }
    }

    static func v3(
        block: [UInt8]?,
        undo: Bool = false,
        records: [(offset: UInt64, data: [UInt8])],
        trailer: [UInt8] = []
    ) -> [UInt8] {
        var bytes = header(version: 3) + [0, block == nil ? 0 : 1, undo ? 1 : 0, 0]
        if let block { bytes += block }
        for record in records {
            bytes += littleEndian(record.offset, width: 8) + [UInt8(record.data.count)] + record.data
            if undo { bytes += [UInt8](repeating: 0xEE, count: record.data.count) }
        }
        return bytes + trailer
    }
}

//
//  MD5ConcurrencyRegressionTests.swift
//  PVHashing
//
//  Regression coverage for the importer hang proven on 2026-08-05.
//
//  `calculateMD5Synchronously` used to block the *calling* thread on a
//  DispatchSemaphore while the hashing itself was dispatched to
//  DispatchQueue.global(.utility) and the completion hopped again to
//  DispatchQueue.global(.userInitiated). Called from inside a `withTaskGroup`
//  (as GameImporter.preProcessQueue does), that parks every Swift cooperative
//  pool thread — leaving nothing to run the continuation that would signal the
//  semaphore. A stack sample of the hung app showed 10 threads in the identical
//  stack, all in semaphore_wait_trap, and the importer never recovered.
//
//  These tests saturate the cooperative pool on purpose. On the broken
//  implementation they deadlock; the `.timeLimit` trait turns that into a
//  failure instead of an infinite hang.
//

import Foundation
import Testing
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
@testable import PVHashing

@Suite("MD5 concurrency regression")
struct MD5ConcurrencyRegressionTests {

    /// Deliberately oversubscribe the cooperative pool: the deadlock only
    /// manifests when concurrent hashers outnumber the available worker threads.
    private static var oversubscribedCount: Int {
        max(ProcessInfo.processInfo.activeProcessorCount * 4, 16)
    }

    /// Writes `count` distinct files and returns their URLs alongside the
    /// expected uppercase MD5 of each, computed in-process from the same bytes.
    private func makeFixtures(count: Int) throws -> (directory: URL, files: [(url: URL, expected: String)]) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("md5-concurrency-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var files: [(URL, String)] = []
        for index in 0..<count {
            // Large enough to span several read chunks, small enough to stay fast.
            var bytes = Data(repeating: UInt8(index % 251), count: 320 * 1024)
            // Make every file's content unique so identical hashes can't mask a bug.
            bytes.append(contentsOf: Array("seed-\(index)".utf8))

            let url = directory.appendingPathComponent("fixture-\(index).bin")
            try bytes.write(to: url)

            let digest = Insecure.MD5.hash(data: bytes)
            let expected = digest.map { String(format: "%02x", $0) }.joined().uppercased()
            files.append((url, expected))
        }
        return (directory, files)
    }

    @Test("Concurrent hashing from the cooperative pool completes and is correct",
          .timeLimit(.minutes(1)))
    func concurrentHashingDoesNotStarveCooperativePool() async throws {
        let count = Self.oversubscribedCount
        let (directory, files) = try makeFixtures(count: count)
        defer { try? FileManager.default.removeItem(at: directory) }

        // This mirrors GameImporter.preProcessQueue's chunked withTaskGroup:
        // many concurrent child tasks each calling the synchronous hash.
        let results = await withTaskGroup(of: (Int, String?).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    (index, FileManager.default.md5ForFile(at: file.url, fromOffset: 0))
                }
            }
            var collected: [(Int, String?)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        #expect(results.count == count)
        for (index, hash) in results {
            #expect(hash == files[index].expected,
                    "MD5 mismatch for fixture-\(index)")
        }
    }

    @Test("Offset hashing is correct and non-blocking under concurrency",
          .timeLimit(.minutes(1)))
    func concurrentOffsetHashing() async throws {
        let offset = 16
        let (directory, files) = try makeFixtures(count: Self.oversubscribedCount)
        defer { try? FileManager.default.removeItem(at: directory) }

        let expectedAtOffset: [String] = try files.map { file in
            let data = try Data(contentsOf: file.url).dropFirst(offset)
            return Insecure.MD5.hash(data: data)
                .map { String(format: "%02x", $0) }.joined().uppercased()
        }

        let results = await withTaskGroup(of: (Int, String?).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    (index, FileManager.default.md5ForFile(at: file.url, fromOffset: UInt(offset)))
                }
            }
            var collected: [(Int, String?)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for (index, hash) in results {
            #expect(hash == expectedAtOffset[index],
                    "Offset MD5 mismatch for fixture-\(index)")
        }
    }

    @Test("A missing file returns nil rather than hanging", .timeLimit(.minutes(1)))
    func missingFileReturnsNil() async throws {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("definitely-absent-\(UUID().uuidString).bin")

        let hash = await Task.detached {
            FileManager.default.md5ForFile(at: missing, fromOffset: 0)
        }.value

        #expect(hash == nil)
    }
}

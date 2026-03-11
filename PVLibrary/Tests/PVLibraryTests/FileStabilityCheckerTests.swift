//
//  FileStabilityCheckerTests.swift
//  PVLibraryTests
//
//  Tests for kqueue-based file stability detection.
//

import XCTest
@testable import PVLibrary

final class FileStabilityCheckerTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileStabilityCheckerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }

    /// A file that already exists and isn't being written to should
    /// stabilize almost immediately (within the quiesce interval).
    func testImmediateStability() async throws {
        let file = tempDir.appendingPathComponent("stable.bin")
        try Data(repeating: 0xAA, count: 1024).write(to: file)

        let start = Date()
        let result = await FileStabilityChecker.waitForStability(
            at: file, quiesceInterval: 0.2, timeout: 5.0
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertTrue(result, "File should be detected as stable")
        XCTAssertLessThan(elapsed, 2.0, "Stable file should resolve quickly")
    }

    /// When a file is continuously written to, the checker should
    /// time out and return `false`.
    func testTimeoutOnContinuousWrites() async throws {
        let file = tempDir.appendingPathComponent("busy.bin")
        try Data(repeating: 0xBB, count: 64).write(to: file)

        let writeTask = Task.detached {
            while !Task.isCancelled {
                if let handle = try? FileHandle(forWritingTo: file) {
                    handle.seekToEndOfFile()
                    handle.write(Data(repeating: 0xCC, count: 8))
                    handle.closeFile()
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        let result = await FileStabilityChecker.waitForStability(
            at: file, quiesceInterval: 0.2, timeout: 1.0
        )

        writeTask.cancel()
        XCTAssertFalse(result, "Continuously written file should time out")
    }

    /// Cancelling the enclosing Task should cause `waitForStability`
    /// to return `false` promptly and release resources.
    func testTaskCancellation() async throws {
        let file = tempDir.appendingPathComponent("cancel.bin")
        try Data(repeating: 0xDD, count: 64).write(to: file)

        let writeTask = Task.detached {
            while !Task.isCancelled {
                if let handle = try? FileHandle(forWritingTo: file) {
                    handle.seekToEndOfFile()
                    handle.write(Data(repeating: 0xEE, count: 8))
                    handle.closeFile()
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        let start = Date()
        let stabilityTask = Task {
            await FileStabilityChecker.waitForStability(
                at: file, quiesceInterval: 0.3, timeout: 30.0
            )
        }

        try await Task.sleep(nanoseconds: 300_000_000)
        stabilityTask.cancel()
        let result = await stabilityTask.value
        let elapsed = Date().timeIntervalSince(start)

        writeTask.cancel()
        XCTAssertFalse(result, "Cancelled task should return false")
        XCTAssertLessThan(elapsed, 5.0, "Cancellation should resolve promptly")
    }

    /// When the file doesn't exist (open fails), the checker should
    /// return `true` optimistically so callers proceed to their own
    /// readability checks.
    func testNonexistentFileReturnsTrue() async {
        let file = tempDir.appendingPathComponent("does-not-exist.bin")
        let result = await FileStabilityChecker.waitForStability(at: file)
        XCTAssertTrue(result, "Missing file should return true (proceed optimistically)")
    }
}

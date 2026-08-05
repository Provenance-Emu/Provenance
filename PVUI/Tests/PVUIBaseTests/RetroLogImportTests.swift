import XCTest
import PVLogging
@testable import PVUIBase

/// Coverage for the log-import path added for #3612: plain-text and ZIP
/// ingestion, `[LEVEL]` parsing, archive ordering, and search filtering.
@MainActor
final class RetroLogImportTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetroLogImportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func write(_ contents: String, to name: String) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Plain text

    func testImportPlainTextPopulatesSessionAndName() throws {
        let url = try write("line one\nline two\nline three", to: "sample.log")
        let vm = RetroLogViewModel()

        try vm.importLog(from: url)

        XCTAssertNotNil(vm.importedSession)
        XCTAssertEqual(vm.importedSession?.name, "sample.log")
        XCTAssertEqual(vm.importedSession?.lines.count, 3)
        XCTAssertEqual(vm.importedSession?.lines.first?.text, "line one")
    }

    func testImportedLineIDsAreUniqueAndOrdered() throws {
        let url = try write("a\nb\nc\nd", to: "ids.txt")
        let vm = RetroLogViewModel()

        try vm.importLog(from: url)

        let ids = vm.importedSession?.lines.map(\.id) ?? []
        XCTAssertEqual(ids, [0, 1, 2, 3])
        XCTAssertEqual(Set(ids).count, ids.count, "line IDs must be unique for ForEach")
    }

    // MARK: - Level parsing

    func testLevelTagsAreParsed() throws {
        let text = """
        [12:00:00.000] [ERROR] boom
        [12:00:00.001] [WARNING] careful
        [12:00:00.002] [INFO] hello
        [12:00:00.003] [DEBUG] details
        [12:00:00.004] [VERBOSE] noise
        """
        let url = try write(text, to: "levels.log")
        let vm = RetroLogViewModel()

        try vm.importLog(from: url)

        let levels = vm.importedSession?.lines.map(\.level) ?? []
        XCTAssertEqual(levels, [.error, .warning, .info, .debug, .verbose])
    }

    func testUntaggedLineHasNoLevel() throws {
        let url = try write("just a bare line", to: "bare.log")
        let vm = RetroLogViewModel()

        try vm.importLog(from: url)

        XCTAssertNil(vm.importedSession?.lines.first?.level)
    }

    // MARK: - Filtering & lifecycle

    func testSearchFiltersImportedLines() throws {
        let url = try write("alpha\nbravo\ncharlie", to: "filter.log")
        let vm = RetroLogViewModel()
        try vm.importLog(from: url)

        vm.searchText = "brav"

        XCTAssertEqual(vm.displayedImportedLines.count, 1)
        XCTAssertEqual(vm.displayedImportedLines.first?.text, "bravo")
    }

    func testSearchIsCaseInsensitive() throws {
        let url = try write("AlphaBeta", to: "case.log")
        let vm = RetroLogViewModel()
        try vm.importLog(from: url)

        vm.searchText = "alphabeta"

        XCTAssertEqual(vm.displayedImportedLines.count, 1)
    }

    func testCloseImportedSessionReturnsToLive() throws {
        let url = try write("x", to: "close.log")
        let vm = RetroLogViewModel()
        try vm.importLog(from: url)
        XCTAssertNotNil(vm.importedSession)

        vm.closeImportedSession()

        XCTAssertNil(vm.importedSession)
        XCTAssertTrue(vm.displayedImportedLines.isEmpty)
    }

    func testCopyableLinesReflectImportedSession() throws {
        let url = try write("only line", to: "copy.log")
        let vm = RetroLogViewModel()
        try vm.importLog(from: url)

        XCTAssertFalse(vm.copyableLinesAreEmpty)

        vm.searchText = "no-such-text"
        XCTAssertTrue(vm.copyableLinesAreEmpty)
    }

    // MARK: - ZIP bundles

    func testImportZipConcatenatesTextEntriesWithDeviceInfoFirst() throws {
        let staging = tempDir.appendingPathComponent("bundle")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try "APP LOG BODY".write(to: staging.appendingPathComponent("app_logs.txt"),
                                 atomically: true, encoding: .utf8)
        try "DEVICE HEADER".write(to: staging.appendingPathComponent("device_info.txt"),
                                  atomically: true, encoding: .utf8)
        // A non-text entry that must be ignored by the importer.
        try Data([0x00, 0x01]).write(to: staging.appendingPathComponent("screenshot.bin"))

        let zipURL = tempDir.appendingPathComponent("logs.zip")
        try zip(directory: staging, to: zipURL)

        let vm = RetroLogViewModel()
        try vm.importLog(from: zipURL)

        let joined = (vm.importedSession?.lines.map(\.text) ?? []).joined(separator: "\n")
        XCTAssertTrue(joined.contains("DEVICE HEADER"))
        XCTAssertTrue(joined.contains("APP LOG BODY"))
        XCTAssertFalse(joined.contains("screenshot.bin"),
                       "non-text entries must not be inlined")

        let headerIdx = try XCTUnwrap(joined.range(of: "DEVICE HEADER")).lowerBound
        let bodyIdx = try XCTUnwrap(joined.range(of: "APP LOG BODY")).lowerBound
        XCTAssertLessThan(headerIdx, bodyIdx, "device_info.txt should be ordered first")
    }

    func testImportUnreadableFileThrows() throws {
        let url = tempDir.appendingPathComponent("does-not-exist.log")
        let vm = RetroLogViewModel()

        XCTAssertThrowsError(try vm.importLog(from: url))
        XCTAssertNil(vm.importedSession, "a failed import must not replace the live session")
    }

    // MARK: - Helpers

    /// Zips a directory using the same NSFileCoordinator approach as the exporter.
    private func zip(directory: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: directory,
                                       options: .forUploading,
                                       error: &coordinatorError) { zipped in
            do {
                try FileManager.default.copyItem(at: zipped, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
    }
}

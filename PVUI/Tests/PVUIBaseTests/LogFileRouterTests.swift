import XCTest
import PVLogging
@testable import PVUIBase

/// Coverage for routing an incoming file URL to the log viewer (#3612): the
/// I/O layer over `IncomingLogFile`, exercised against real files on disk.
final class LogFileRouterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogFileRouterTests-\(UUID().uuidString)")
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

    // MARK: - Extension only

    func testLogExtensionIsPlainLogWithoutReadingContents() {
        // The file does not exist on purpose: a `.log` must not be opened to decide.
        let url = tempDir.appendingPathComponent("missing.log")
        XCTAssertEqual(LogFileRouter.classify(fileURL: url), .plainLog)
    }

    func testRomExtensionIsOther() throws {
        let url = try write("not really a rom", to: "game.nes")
        XCTAssertEqual(LogFileRouter.classify(fileURL: url), .other)
    }

    // MARK: - ZIP bundles

    func testExportedBundleZipIsLogBundle() throws {
        let staging = tempDir.appendingPathComponent("pv_log_export_test")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try "HEADER".write(to: staging.appendingPathComponent(IncomingLogFile.bundleDeviceInfoName),
                           atomically: true, encoding: .utf8)
        try "BODY".write(to: staging.appendingPathComponent(IncomingLogFile.bundleAppLogsName),
                         atomically: true, encoding: .utf8)
        let zipURL = tempDir.appendingPathComponent("provenance_logs.zip")
        try zip(directory: staging, to: zipURL)

        XCTAssertEqual(LogFileRouter.classify(fileURL: zipURL), .logBundle)
    }

    func testRomZipIsOther() throws {
        let staging = tempDir.appendingPathComponent("romset")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data([0x4E, 0x45, 0x53, 0x1A]).write(to: staging.appendingPathComponent("Game.nes"))
        try "notes".write(to: staging.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
        let zipURL = tempDir.appendingPathComponent("romset.zip")
        try zip(directory: staging, to: zipURL)

        XCTAssertEqual(LogFileRouter.classify(fileURL: zipURL), .other)
    }

    func testCorruptZipIsOther() throws {
        let url = tempDir.appendingPathComponent("broken.zip")
        try Data("this is not a zip".utf8).write(to: url)
        XCTAssertEqual(LogFileRouter.classify(fileURL: url), .other)
    }

    // MARK: - Text files

    func testExportedTextIsPlainLog() throws {
        let url = try write(IncomingLogFile.exportHeader + "\nDate: now\n[12:00:00.000] [INFO] hi", to: "export.txt")
        XCTAssertEqual(LogFileRouter.classify(fileURL: url), .plainLog)
    }

    func testTextWithMultibytePastThePrefixIsStillRecognised() throws {
        // Fill past the prefix window with 3-byte characters so the fixed-size
        // read is likely to end mid-character.
        let filler = String(repeating: "€", count: IncomingLogFile.textPrefixByteCount)
        let url = try write(IncomingLogFile.exportHeader + "\n" + filler, to: "wide.txt")
        XCTAssertEqual(LogFileRouter.classify(fileURL: url), .plainLog)
    }

    func testRetroArchConfigTextIsOther() throws {
        let url = try write("video_driver = \"vulkan\"\nmenu_driver = \"ozone\"", to: "retroarch.txt")
        XCTAssertEqual(LogFileRouter.classify(fileURL: url), .other)
    }

    func testMissingTextFileIsOther() {
        let url = tempDir.appendingPathComponent("missing.txt")
        XCTAssertEqual(LogFileRouter.classify(fileURL: url), .other)
    }

    // MARK: - Helpers

    /// Zips a directory the same way the exporter does, so entries are nested
    /// under the folder name like a real `provenance_logs_<ts>.zip`.
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

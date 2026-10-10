import XCTest
@testable import PVDevHarnessKit

final class HarnessArgumentsTests: XCTestCase {
    func testNoROMMeansNormalLaunch() {
        XCTAssertNil(HarnessArguments.parse(["/app", "-NSDoubleLocalizedStrings", "YES"]))
    }

    func testDefaults() throws {
        let args = try XCTUnwrap(HarnessArguments.parse(["/app", "-PVHarnessROM", "/tmp/a.gba"]))
        XCTAssertEqual(args.romPath, "/tmp/a.gba")
        XCTAssertNil(args.coreIdentifier)
        XCTAssertEqual(args.frames, HarnessArguments.defaultFrames)
        XCTAssertNil(args.outputPath)
        XCTAssertTrue(args.exitWhenDone)
    }

    func testAllArguments() throws {
        let args = try XCTUnwrap(HarnessArguments.parse([
            "/app", "-PVHarnessROM", "Documents/a.gba", "-PVHarnessCore", "com.provenance.core.mgba",
            "-PVHarnessFrames", "120", "-PVHarnessOut", "Documents/out", "-PVHarnessExit", "0",
        ]))
        XCTAssertEqual(args.coreIdentifier, "com.provenance.core.mgba")
        XCTAssertEqual(args.frames, 120)
        XCTAssertEqual(args.outputPath, "Documents/out")
        XCTAssertFalse(args.exitWhenDone)
    }

    func testBadFramesFallBackAndClamp() throws {
        XCTAssertEqual(HarnessArguments.parse(["-PVHarnessROM", "a", "-PVHarnessFrames", "abc"])?.frames, 300)
        XCTAssertEqual(HarnessArguments.parse(["-PVHarnessROM", "a", "-PVHarnessFrames", "0"])?.frames, 1)
        XCTAssertEqual(HarnessArguments.parse(["-PVHarnessROM", "a", "-PVHarnessFrames", "99999999"])?.frames, HarnessArguments.maxFrames)
    }

    func testMissingValueIsIgnored() {
        XCTAssertNil(HarnessArguments.parse(["-PVHarnessROM", "-PVHarnessFrames", "10"]))
    }

    func testPathsResolveAgainstHome() throws {
        let home = URL(fileURLWithPath: "/container", isDirectory: true)
        let relative = try XCTUnwrap(HarnessArguments.parse(["-PVHarnessROM", "Documents/a.gba", "-PVHarnessOut", "Documents/out"]))
        XCTAssertEqual(relative.romURL(home: home).path, "/container/Documents/a.gba")
        XCTAssertEqual(relative.outputDirectory(home: home, documents: home, now: Date()).path, "/container/Documents/out")
        let absolute = try XCTUnwrap(HarnessArguments.parse(["-PVHarnessROM", "/roms/a.gba"]))
        XCTAssertEqual(absolute.romURL(home: home).path, "/roms/a.gba")
    }

    func testDefaultOutputDirectoryIsTimestamped() throws {
        let args = try XCTUnwrap(HarnessArguments.parse(["-PVHarnessROM", "a"]))
        let docs = URL(fileURLWithPath: "/docs", isDirectory: true)
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(args.outputDirectory(home: docs, documents: docs, now: date).path, "/docs/Harness/19700101-000000-000")
    }
}

final class HarnessOutputTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try HarnessOutput.prepare(dir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testReportRoundTrips() throws {
        let report = HarnessReport(core: "c", game: "g", frames: 300, frameCountSource: "estimated",
                                   frameInterval: 1.0 / 60.0, fps: 60, waitedSeconds: 5, elapsedSeconds: 9.5)
        try HarnessOutput.writeReport(report, to: dir)
        let data = try Data(contentsOf: dir.appendingPathComponent(HarnessOutput.framesFile))
        XCTAssertEqual(try JSONDecoder().decode(HarnessReport.self, from: data), report)
    }

    func testErrorAndScreenshotAndLog() throws {
        try HarnessOutput.writeError("boom", to: dir)
        try HarnessOutput.writeScreenshot(Data([0x89, 0x50]), to: dir)
        let log = dir.appendingPathComponent("source.log")
        try "line".write(to: log, atomically: true, encoding: .utf8)
        try HarnessOutput.copyLog(from: log, to: dir)
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent(HarnessOutput.errorFile), encoding: .utf8), "boom\n")
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(HarnessOutput.screenshotFile)), Data([0x89, 0x50]))
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent(HarnessOutput.logFile), encoding: .utf8), "line")
    }

    func testMissingLogStillWritesAFile() throws {
        try HarnessOutput.copyLog(from: nil, to: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(HarnessOutput.logFile).path))
    }

    func testWaitSeconds() {
        XCTAssertEqual(HarnessOutput.waitSeconds(frames: 300, frameInterval: 1.0 / 60.0), 5, accuracy: 0.0001)
        XCTAssertEqual(HarnessOutput.waitSeconds(frames: 120, frameInterval: 0), 2, accuracy: 0.0001)
    }

    func testReportEncodesNonFiniteDoubles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try HarnessOutput.prepare(dir)
        let report = HarnessReport(core: "c", game: "g", frames: 1, frameCountSource: "estimated",
                                   frameInterval: 0, fps: .infinity, waitedSeconds: 0, elapsedSeconds: .nan)
        XCTAssertNoThrow(try HarnessOutput.writeReport(report, to: dir))
    }
}

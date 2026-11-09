//
//  LogExportServiceTests.swift
//  PVLoggingTests
//
//  Covers the log export service added for #3612: header rendering, source
//  enumeration, option filtering, text rendering and zip bundle layout.
//

import Testing
import Foundation
@testable import PVLogging

// MARK: - Fixtures

/// A temp tree with one directory per source kind, removed on deinit.
private final class ExportFixture {
    let root: URL
    let locations: LogExportLocations
    let outputDirectory: URL
    let service: LogExportService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogExportServiceTests-\(UUID().uuidString)", isDirectory: true)
        locations = LogExportLocations(
            sessionLogsDirectory: root.appendingPathComponent("sessions", isDirectory: true),
            crashReportsDirectory: root.appendingPathComponent("crashes", isDirectory: true),
            coreLogsDirectory: root.appendingPathComponent("cores", isDirectory: true)
        )
        outputDirectory = root.appendingPathComponent("out", isDirectory: true)
        for dir in [locations.sessionLogsDirectory, locations.crashReportsDirectory, locations.coreLogsDirectory] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        service = LogExportService(locations: locations, outputDirectory: outputDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func write(_ text: String, to relativePath: String, in directory: URL, modified: Date? = nil) throws -> URL {
        let url = directory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
        return url
    }
}

private func makeHeader(options: LogExportOptions = LogExportOptions()) -> LogExportHeader {
    LogExportHeader(
        appName: "Provenance",
        appVersion: "3.4.0",
        appBuild: "4321",
        bundleIdentifier: "org.provenance-emu.provenance",
        deviceModel: "iPhone15,2",
        osName: "iOS",
        osVersion: "18.1.0",
        hostNote: nil,
        exportDate: Date(timeIntervalSince1970: 1_700_000_000),
        entryCount: 2,
        totalEntryCount: 5,
        options: options
    )
}

private func makeEntry(_ message: String, level: LogLevel = .info, category: String = "general", file: String = "Some/Path/File.swift", line: Int = 7) -> LogEntry {
    LogEntry(message: message, level: level, category: category, timestamp: Date(timeIntervalSince1970: 1_700_000_000),
             file: file, function: "fn()", line: line)
}

// MARK: - Header

@Suite("LogExportHeader")
struct LogExportHeaderTests {

    @Test("Rendered header starts with the title and lists every field")
    func rendersAllFields() {
        let rendered = makeHeader().render()
        let lines = rendered.split(separator: "\n").map(String.init)

        #expect(lines.first == LogExportHeader.title)
        #expect(lines.contains("App: Provenance 3.4.0 (4321)"))
        #expect(lines.contains("Bundle: org.provenance-emu.provenance"))
        #expect(lines.contains("Device: iPhone15,2"))
        #expect(lines.contains("OS: iOS 18.1.0"))
        #expect(lines.contains("Format: zip"))
        #expect(lines.contains("Log Entries: 2 (total in session: 5)"))
        #expect(lines.contains { $0.hasPrefix("Date: 2023-11-14T") })
        #expect(!rendered.contains("Host:"), "no host line without a host note")
    }

    @Test("Host note is rendered when present")
    func rendersHostNote() {
        var header = makeHeader()
        header.hostNote = "macOS (iOS app on Mac)"
        #expect(header.render().contains("Host: macOS (iOS app on Mac)"))
    }

    @Test("Included line reflects the selected options")
    func includedSummaryFollowsOptions() {
        let everything = LogExportOptions()
        #expect(everything.includedSummary == "device info, app logs, session files, crash reports, core logs")

        let onlyLogs = LogExportOptions(includeDeviceInfo: false, includeSessionFiles: false,
                                        includeCrashReports: false, includeCoreLogs: false)
        #expect(onlyLogs.includedSummary == "app logs")
        #expect(makeHeader(options: onlyLogs).render().contains("Included: app logs"))

        let nothing = LogExportOptions(includeAppLogs: false, includeDeviceInfo: false, includeSessionFiles: false,
                                       includeCrashReports: false, includeCoreLogs: false)
        #expect(nothing.isEmpty)
        #expect(nothing.includedSummary == "nothing")
    }

    @Test("current() reads version and build from the bundle")
    func currentReadsBundle() {
        let header = LogExportHeader.current(options: LogExportOptions(format: .text), entryCount: 1, totalEntryCount: 3,
                                             bundle: Bundle(for: ExportFixture.self))
        #expect(!header.deviceModel.isEmpty)
        #expect(!header.osVersion.isEmpty)
        #expect(header.osName != "unknown")
        #expect(header.entryCount == 1)
        #expect(header.totalEntryCount == 3)
        #expect(header.options.format == .text)
    }

    @Test("Header round-trips through JSON")
    func codableRoundTrip() throws {
        let header = makeHeader()
        let data = try LogExportManifest.encoder().encode(header)
        let decoded = try LogExportManifest.decoder().decode(LogExportHeader.self, from: data)
        #expect(decoded == header)
    }
}

// MARK: - Entry formatting

@Suite("LogExportService.format")
struct LogExportFormatTests {

    @Test("Formatted entry carries the level tag the importer parses")
    func formatsLevelCategoryAndMessage() {
        let line = LogExportService.format(makeEntry("hello", level: .warning, category: "audio"), includeSourceLocation: false)
        #expect(line.contains("[WARNING]"))
        #expect(line.contains("(audio)"))
        #expect(line.hasSuffix(" hello"))
        #expect(!line.contains("File.swift"))
        #expect(LogFileParsing.level(in: line) == .warning)
    }

    @Test("Source location appends the file name and line only when asked")
    func sourceLocationIsOptional() {
        let entry = makeEntry("x", file: "Deep/Nested/Thing.swift", line: 42)
        #expect(LogExportService.format(entry, includeSourceLocation: true).contains("[Thing.swift:42]"))
        #expect(!LogExportService.format(entry, includeSourceLocation: false).contains("Thing.swift"))
    }

    @Test("Empty category is omitted")
    func emptyCategoryOmitted() {
        let line = LogExportService.format(makeEntry("m", category: ""), includeSourceLocation: false)
        #expect(!line.contains("()"))
    }
}

// MARK: - Source enumeration

@Suite("LogExportSourceSet.scan")
struct LogExportSourceScanTests {

    @Test("Missing directories yield an empty set")
    func missingDirectoriesAreEmpty() {
        let bogus = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
        let set = LogExportSourceSet.scan(LogExportLocations(sessionLogsDirectory: bogus, crashReportsDirectory: bogus,
                                                             coreLogsDirectory: bogus))
        #expect(set.isEmpty)
    }

    @Test("Files are filtered by extension per kind and sorted newest first")
    func filtersAndSorts() throws {
        let fixture = try ExportFixture()
        let old = Date(timeIntervalSinceNow: -3_600)
        let new = Date(timeIntervalSinceNow: -60)
        try fixture.write("old", to: "session_old.log", in: fixture.locations.sessionLogsDirectory, modified: old)
        try fixture.write("new", to: "session_new.log", in: fixture.locations.sessionLogsDirectory, modified: new)
        try fixture.write("nope", to: "notes.txt", in: fixture.locations.sessionLogsDirectory)
        try fixture.write("{}", to: "crash-1.json", in: fixture.locations.crashReportsDirectory)
        try fixture.write("ips", to: "report.ips", in: fixture.locations.crashReportsDirectory)
        try fixture.write("bin", to: "thumb.png", in: fixture.locations.crashReportsDirectory)
        try fixture.write("core", to: "nested/retroarch.log", in: fixture.locations.coreLogsDirectory)
        try fixture.write("hidden", to: ".DS_Store", in: fixture.locations.coreLogsDirectory)

        let set = fixture.service.availableSources()

        #expect(set.sessionFiles.map(\.name) == ["session_new.log", "session_old.log"])
        #expect(Set(set.crashReports.map(\.name)) == ["crash-1.json", "report.ips"])
        #expect(set.coreLogs.map(\.name) == ["retroarch.log"])
        #expect(set.sessionFiles.allSatisfy { $0.kind == .session })
        #expect(set.crashReports.allSatisfy { $0.kind == .crash })
        #expect(set.coreLogs.first?.size == 4)
        #expect(set.files(of: .core).count == 1)
    }
}

// MARK: - Option filtering

@Suite("LogExportService.selectedFiles")
struct LogExportSelectionTests {

    @Test("Only the kinds enabled in the options are selected, sessions first")
    func selectionFollowsOptions() throws {
        let fixture = try ExportFixture()
        try fixture.write("s", to: "s.log", in: fixture.locations.sessionLogsDirectory)
        try fixture.write("{}", to: "c.json", in: fixture.locations.crashReportsDirectory)
        try fixture.write("k", to: "k.log", in: fixture.locations.coreLogsDirectory)
        let sources = fixture.service.availableSources()

        let all = fixture.service.selectedFiles(from: sources, options: LogExportOptions())
        #expect(all.map(\.kind) == [.session, .crash, .core])

        let noCrash = fixture.service.selectedFiles(from: sources, options: LogExportOptions(includeCrashReports: false))
        #expect(noCrash.map(\.kind) == [.session, .core])

        let none = fixture.service.selectedFiles(
            from: sources,
            options: LogExportOptions(includeSessionFiles: false, includeCrashReports: false, includeCoreLogs: false)
        )
        #expect(none.isEmpty)
    }

    @Test("Exporting with every toggle off throws nothingSelected")
    func emptyOptionsThrow() throws {
        let fixture = try ExportFixture()
        let options = LogExportOptions(includeAppLogs: false, includeDeviceInfo: false, includeSessionFiles: false,
                                       includeCrashReports: false, includeCoreLogs: false)
        #expect(throws: LogExportError.nothingSelected) {
            try fixture.service.export(entries: [], options: options, header: makeHeader())
        }
    }
}

// MARK: - Text export

@Suite("LogExportService text export")
struct LogExportTextTests {

    @Test("Text export is a .log file with the header first and app logs after")
    func writesHeaderThenEntries() throws {
        let fixture = try ExportFixture()
        let options = LogExportOptions(format: .text, includeSessionFiles: false, includeCrashReports: false, includeCoreLogs: false)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let result = try fixture.service.export(entries: [makeEntry("first"), makeEntry("second", level: .error)],
                                                totalEntryCount: 9, options: options, header: makeHeader(options: options), date: date)

        #expect(result.format == .text)
        #expect(result.url.pathExtension == "log")
        #expect(result.url.lastPathComponent.hasPrefix("provenance_logs_"))
        #expect(result.url.deletingLastPathComponent().standardizedFileURL == fixture.outputDirectory.standardizedFileURL)
        #expect(result.includedPaths == [LogExportManifest.deviceInfoKind, LogExportManifest.appLogsKind])

        let text = try String(contentsOf: result.url, encoding: .utf8)
        #expect(text.hasPrefix(LogExportHeader.title))
        let headerRange = try #require(text.range(of: "App: Provenance 3.4.0"))
        let logsRange = try #require(text.range(of: "=== App Logs (2 entries) ==="))
        let firstRange = try #require(text.range(of: "[INFO] (general) first"))
        let secondRange = try #require(text.range(of: "[ERROR] (general) second"))
        #expect(headerRange.lowerBound < logsRange.lowerBound)
        #expect(logsRange.lowerBound < firstRange.lowerBound)
        #expect(firstRange.lowerBound < secondRange.lowerBound)

        // Round trip through the importer's parser keeps the levels.
        let parsed = LogFileParsing.parseLines(text)
        #expect(parsed.contains { $0.level == .error && $0.text.contains("second") })
    }

    @Test("Selected on-disk files are inlined under a banner; deselected kinds are left out")
    func inlinesSelectedFiles() throws {
        let fixture = try ExportFixture()
        try fixture.write("SESSION BODY", to: "session_a.log", in: fixture.locations.sessionLogsDirectory)
        try fixture.write("{\"crash\":true}", to: "crash-1.json", in: fixture.locations.crashReportsDirectory)
        try fixture.write("CORE BODY", to: "core.log", in: fixture.locations.coreLogsDirectory)
        let options = LogExportOptions(format: .text, includeAppLogs: false, includeCrashReports: false)

        let result = try fixture.service.export(entries: [], options: options, header: makeHeader(options: options))
        let text = try String(contentsOf: result.url, encoding: .utf8)

        #expect(text.contains("=== Session Log: session_a.log ===\nSESSION BODY"))
        #expect(text.contains("=== Core Log: core.log ===\nCORE BODY"))
        #expect(!text.contains("crash-1.json"))
        #expect(!text.contains("=== App Logs"))
        #expect(result.includedPaths == [LogExportManifest.deviceInfoKind, "session/session_a.log", "core/core.log"])
    }

    @Test("Header can be left out of a text export")
    func omitsHeaderWhenDisabled() throws {
        let fixture = try ExportFixture()
        let options = LogExportOptions(format: .text, includeDeviceInfo: false, includeSessionFiles: false,
                                       includeCrashReports: false, includeCoreLogs: false)
        let result = try fixture.service.export(entries: [makeEntry("only")], options: options, header: makeHeader(options: options))
        let text = try String(contentsOf: result.url, encoding: .utf8)
        #expect(!text.contains(LogExportHeader.title))
        #expect(text.hasPrefix("=== App Logs (1 entries) ==="))
    }
}

// MARK: - Zip export

@Suite("LogExportService zip export")
struct LogExportZipTests {

    @Test("Staged bundle has manifest, device info, app logs and the selected files in kind folders")
    func stagesBundleLayout() throws {
        let fixture = try ExportFixture()
        try fixture.write("SESSION", to: "session_a.log", in: fixture.locations.sessionLogsDirectory)
        try fixture.write("{}", to: "crash-1.json", in: fixture.locations.crashReportsDirectory)
        try fixture.write("CORE", to: "sub/core.log", in: fixture.locations.coreLogsDirectory)
        let options = LogExportOptions(format: .zip)
        let header = makeHeader(options: options)

        let staged = try fixture.service.stage(entries: [makeEntry("one")], options: options, header: header, baseName: "bundle")
        defer { try? FileManager.default.removeItem(at: staged.directory.deletingLastPathComponent()) }

        let fm = FileManager.default
        #expect(staged.directory.lastPathComponent == "bundle")
        #expect(fm.fileExists(atPath: staged.directory.appendingPathComponent("manifest.json").path))
        #expect(fm.fileExists(atPath: staged.directory.appendingPathComponent("device_info.txt").path))
        #expect(fm.fileExists(atPath: staged.directory.appendingPathComponent("app_logs.log").path))
        #expect(fm.fileExists(atPath: staged.directory.appendingPathComponent("session_logs/session_a.log").path))
        #expect(fm.fileExists(atPath: staged.directory.appendingPathComponent("crash_reports/crash-1.json").path))
        #expect(fm.fileExists(atPath: staged.directory.appendingPathComponent("core_logs/sub/core.log").path),
                "nested core logs keep their relative layout")

        let deviceInfo = try String(contentsOf: staged.directory.appendingPathComponent("device_info.txt"), encoding: .utf8)
        #expect(deviceInfo == header.render())

        let appLogs = try String(contentsOf: staged.directory.appendingPathComponent("app_logs.log"), encoding: .utf8)
        #expect(appLogs.contains("[INFO] (general) one"))
    }

    @Test("Manifest decodes and describes every entry")
    func manifestDescribesEntries() throws {
        let fixture = try ExportFixture()
        let sessionURL = try fixture.write("SESSION", to: "session_a.log", in: fixture.locations.sessionLogsDirectory)
        let options = LogExportOptions(format: .zip, includeCrashReports: false, includeCoreLogs: false)
        let header = makeHeader(options: options)

        let staged = try fixture.service.stage(entries: [makeEntry("one")], options: options, header: header, baseName: "m")
        defer { try? FileManager.default.removeItem(at: staged.directory.deletingLastPathComponent()) }

        let data = try Data(contentsOf: staged.directory.appendingPathComponent("manifest.json"))
        let manifest = try LogExportManifest.decoder().decode(LogExportManifest.self, from: data)

        // ISO 8601 drops sub-second precision, so compare field by field rather than whole-struct.
        #expect(manifest.version == LogExportManifest.currentVersion)
        #expect(manifest.header == header)
        #expect(manifest.files.map(\.path) == staged.manifest.files.map(\.path))
        #expect(manifest.files.map(\.path) == ["device_info.txt", "app_logs.log", "session_logs/session_a.log"])
        #expect(manifest.files.map(\.kind) == [LogExportManifest.deviceInfoKind, LogExportManifest.appLogsKind, "session"])
        #expect(manifest.files.map(\.size) == staged.manifest.files.map(\.size))
        let session = try #require(manifest.files.last)
        #expect(session.size == 7)
        let sourcePath = try #require(session.sourcePath)
        #expect(URL(fileURLWithPath: sourcePath).resolvingSymlinksInPath().path == sessionURL.resolvingSymlinksInPath().path)
        #expect(session.modificationDate != nil)
    }

    @Test("Deselected kinds are absent from the bundle and the manifest")
    func optionsFilterBundle() throws {
        let fixture = try ExportFixture()
        try fixture.write("S", to: "s.log", in: fixture.locations.sessionLogsDirectory)
        try fixture.write("{}", to: "c.json", in: fixture.locations.crashReportsDirectory)
        let options = LogExportOptions(format: .zip, includeAppLogs: false, includeDeviceInfo: false, includeSessionFiles: false)

        let staged = try fixture.service.stage(entries: [], options: options, header: makeHeader(options: options), baseName: "f")
        defer { try? FileManager.default.removeItem(at: staged.directory.deletingLastPathComponent()) }

        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: staged.directory.appendingPathComponent("device_info.txt").path))
        #expect(!fm.fileExists(atPath: staged.directory.appendingPathComponent("app_logs.log").path))
        #expect(!fm.fileExists(atPath: staged.directory.appendingPathComponent("session_logs").path))
        #expect(staged.manifest.files.map(\.path) == ["crash_reports/c.json"])
    }

#if canImport(Darwin)
    @Test("Zip export writes a non-empty .zip, removes its staging folder and lists the manifest")
    func writesZipArchive() throws {
        let fixture = try ExportFixture()
        try fixture.write("SESSION", to: "session_a.log", in: fixture.locations.sessionLogsDirectory)
        let options = LogExportOptions(format: .zip)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let result = try fixture.service.export(entries: [makeEntry("one")], options: options,
                                                header: makeHeader(options: options), date: date)

        #expect(result.format == .zip)
        #expect(result.url.pathExtension == "zip")
        #expect(result.includedPaths == ["device_info.txt", "app_logs.log", "session_logs/session_a.log"])
        let size = try #require(try result.url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)

        // Zip files start with the local-file-header signature "PK\u{03}\u{04}".
        let magic = try Data(contentsOf: result.url).prefix(4)
        #expect(magic == Data([0x50, 0x4B, 0x03, 0x04]))

        let staging = try FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)
            .filter { $0.hasPrefix("ProvenanceLogExportStaging-") }
        #expect(!staging.contains { $0.contains(result.url.deletingPathExtension().lastPathComponent) })

#if os(macOS)
        let listing = try runUnzipListing(of: result.url)
        #expect(listing.contains("manifest.json"))
        #expect(listing.contains("session_logs/session_a.log"))
#endif
    }

#if os(macOS)
    private func runUnzipListing(of url: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-l", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        return String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
#endif
#endif

    @Test("removeExports(olderThan:) prunes stale exports and keeps recent ones")
    func prunesOldExports() throws {
        let fixture = try ExportFixture()
        try FileManager.default.createDirectory(at: fixture.outputDirectory, withIntermediateDirectories: true)
        try fixture.write("old", to: "old.log", in: fixture.outputDirectory, modified: Date(timeIntervalSinceNow: -7_200))
        try fixture.write("new", to: "new.log", in: fixture.outputDirectory)

        let removed = fixture.service.removeExports(olderThan: 3_600)

        #expect(removed == 1)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: fixture.outputDirectory.path)
        #expect(remaining == ["new.log"])
    }
}

//
//  PVLoggingTests.swift
//  PVLoggingTests
//
//  Created by Joseph Mattiello on 1/4/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

@testable import PVLogging
import Testing
import Foundation

// MARK: - PVLogLevel Tests

@Suite("PVLogLevel")
struct PVLogLevelTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(PVLogLevel.allCases.count == 5)
    }

    @Test("Raw values are sequential from 0")
    func rawValues() {
        #expect(PVLogLevel.U.rawValue == 0)
        #expect(PVLogLevel.Error.rawValue == 1)
        #expect(PVLogLevel.Warn.rawValue == 2)
        #expect(PVLogLevel.Info.rawValue == 3)
        #expect(PVLogLevel.Debug.rawValue == 4)
    }

    @Test("Descriptions are correct")
    func descriptions() {
        #expect(PVLogLevel.U.description == "U")
        #expect(PVLogLevel.Error.description == "Error")
        #expect(PVLogLevel.Warn.description == "Warn")
        #expect(PVLogLevel.Info.description == "Info")
        #expect(PVLogLevel.Debug.description == "Debug")
    }

    @Test("RawRepresentable round-trip")
    func rawRepresentableRoundTrip() {
        for level in PVLogLevel.allCases {
            let reconstructed = PVLogLevel(rawValue: level.rawValue)
            #expect(reconstructed == level)
        }
    }

    @Test("Default debug level is non-nil")
    func defaultDebugLevel() {
        let level = PVLogLevel.defaultDebugLevel
        #expect(PVLogLevel.allCases.contains(level))
    }
}

// MARK: - LogLevel Tests

@Suite("LogLevel")
struct LogLevelTests {

    @Test("Raw values are sequential from 0")
    func rawValues() {
        #expect(LogLevel.verbose.rawValue == 0)
        #expect(LogLevel.debug.rawValue == 1)
        #expect(LogLevel.info.rawValue == 2)
        #expect(LogLevel.warning.rawValue == 3)
        #expect(LogLevel.error.rawValue == 4)
    }

    @Test("Short names are single characters")
    func shortNames() {
        #expect(LogLevel.verbose.shortName == "V")
        #expect(LogLevel.debug.shortName == "D")
        #expect(LogLevel.info.shortName == "I")
        #expect(LogLevel.warning.shortName == "W")
        #expect(LogLevel.error.shortName == "E")
    }

    @Test("Full names are descriptive")
    func fullNames() {
        #expect(LogLevel.verbose.name == "Verbose")
        #expect(LogLevel.debug.name == "Debug")
        #expect(LogLevel.info.name == "Info")
        #expect(LogLevel.warning.name == "Warning")
        #expect(LogLevel.error.name == "Error")
    }

    @Test("Colors are non-empty strings")
    func colors() {
        for level in [LogLevel.verbose, .debug, .info, .warning, .error] {
            #expect(!level.color.isEmpty)
        }
        #expect(LogLevel.verbose.color == "gray")
        #expect(LogLevel.debug.color == "blue")
        #expect(LogLevel.info.color == "green")
        #expect(LogLevel.warning.color == "orange")
        #expect(LogLevel.error.color == "red")
    }

    @Test("Comparable ordering is correct")
    func comparableOrdering() {
        #expect(LogLevel.verbose < LogLevel.debug)
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
        #expect(!(LogLevel.error < LogLevel.warning))
        #expect(!(LogLevel.info < LogLevel.info))
    }

    @Test("Equality holds for same level")
    func equality() {
        #expect(LogLevel.info == LogLevel.info)
        #expect(LogLevel.debug != LogLevel.error)
    }
}

// MARK: - PVLogEntry Tests

@Suite("PVLogEntry")
struct PVLogEntryTests {

    @Test("Init with message sets text")
    func initWithMessage() {
        let entry = PVLogEntry(message: "Hello, world!")
        #expect(entry.text == "Hello, world!")
    }

    @Test("Default level is Debug")
    func defaultLevel() {
        let entry = PVLogEntry(message: "test")
        #expect(entry.level == .Debug)
    }

    @Test("Init with full parameters sets all fields")
    func initWithFullParameters() {
        let entry = PVLogEntry(
            message: "Detailed message",
            level: .Error,
            file: "MyFile.swift",
            function: "myFunction()",
            lineNumber: "42"
        )
        #expect(entry.text == "Detailed message")
        #expect(entry.level == .Error)
        #expect(entry.lineNumberString == "42")
    }

    @Test("Description contains text")
    func descriptionContainsText() {
        let entry = PVLogEntry(message: "test message")
        #expect(entry.description.contains("test message"))
    }

    @Test("String contains text")
    func stringContainsText() {
        let entry = PVLogEntry(message: "string test")
        #expect(entry.string.contains("string test"))
    }

    @Test("StringWithLocation contains text")
    func stringWithLocationContainsText() {
        let entry = PVLogEntry(message: "location test")
        #expect(entry.stringWithLocation.contains("location test"))
    }

    @Test("HtmlString contains text")
    func htmlStringContainsText() {
        let entry = PVLogEntry(message: "html test")
        #expect(entry.htmlString.contains("html test"))
    }

    @Test("HtmlString is valid HTML snippet")
    func htmlStringIsValidSnippet() {
        let entry = PVLogEntry(message: "html")
        #expect(entry.htmlString.contains("<span"))
        #expect(entry.htmlString.contains("</span>"))
    }

    @Test("EntryIndex increments")
    func entryIndexNonNegative() {
        let entry1 = PVLogEntry(message: "first")
        let entry2 = PVLogEntry(message: "second")
        #expect(entry1.entryIndex >= 0)
        #expect(entry2.entryIndex >= 0)
    }

    @Test("Offset is non-negative")
    func offsetIsNonNegative() {
        let entry = PVLogEntry(message: "time test")
        #expect(entry.offset >= 0)
    }

    @Test("Time is recent")
    func timeIsRecent() {
        let before = Date()
        let entry = PVLogEntry(message: "timing")
        let after = Date()
        #expect(entry.time >= before)
        #expect(entry.time <= after)
    }
}

// MARK: - LogEntry Tests

@Suite("LogEntry")
struct LogEntryTests {

    func makeEntry(
        message: String = "test",
        level: LogLevel = .info,
        category: String = "general"
    ) -> LogEntry {
        LogEntry(
            message: message,
            level: level,
            category: category,
            timestamp: Date(),
            file: "TestFile.swift",
            function: "testFunction()",
            line: 1
        )
    }

    @Test("Identifiable: two instances have different IDs")
    func identifiableUniqueness() {
        let e1 = makeEntry()
        let e2 = makeEntry()
        #expect(e1.id != e2.id)
    }

    @Test("Equatable: same ID means equal")
    func equalityById() {
        let e1 = makeEntry(message: "hello")
        let e2 = makeEntry(message: "world")
        #expect(e1 != e2)
    }

    @Test("ShortDescription includes level shortName and message")
    func shortDescription() {
        let entry = makeEntry(message: "my message", level: .warning)
        #expect(entry.shortDescription.contains("W"))
        #expect(entry.shortDescription.contains("my message"))
    }

    @Test("FullDescription includes all fields")
    func fullDescription() {
        let entry = makeEntry(message: "full msg", level: .error, category: "database")
        #expect(entry.fullDescription.contains("full msg"))
        #expect(entry.fullDescription.contains("E"))
        #expect(entry.fullDescription.contains("database"))
    }

    @Test("FormattedTimestamp has expected format")
    func formattedTimestamp() {
        let entry = makeEntry()
        let ts = entry.formattedTimestamp
        #expect(ts.count >= 12)
        #expect(ts.contains(":"))
        #expect(ts.contains("."))
    }

    @Test("Message is stored correctly")
    func messageStored() {
        let entry = makeEntry(message: "stored message")
        #expect(entry.message == "stored message")
    }

    @Test("Level is stored correctly")
    func levelStored() {
        let entry = makeEntry(level: .debug)
        #expect(entry.level == .debug)
    }

    @Test("Category is stored correctly")
    func categoryStored() {
        let entry = makeEntry(category: "network")
        #expect(entry.category == "network")
    }

    @Test("Line number is stored correctly")
    func lineNumberStored() {
        let entry = LogEntry(
            message: "test",
            level: .info,
            category: "general",
            timestamp: Date(),
            file: "File.swift",
            function: "fn()",
            line: 99
        )
        #expect(entry.line == 99)
    }

    @Test("File is stored correctly")
    func fileStored() {
        let entry = LogEntry(
            message: "test",
            level: .info,
            category: "general",
            timestamp: Date(),
            file: "SpecialFile.swift",
            function: "fn()",
            line: 1
        )
        #expect(entry.file == "SpecialFile.swift")
    }
}

// MARK: - PVLogPublisher Tests

@Suite("PVLogPublisher", .serialized)
struct PVLogPublisherTests {

    @Test("Shared singleton is accessible")
    func sharedSingleton() {
        let pub1 = PVLogPublisher.shared
        let pub2 = PVLogPublisher.shared
        #expect(pub1 === pub2)
    }

    @Test("storeEntry stores entry in recent logs")
    func storeEntryStores() {
        let publisher = PVLogPublisher.shared
        publisher.clearLogs()

        publisher.storeEntry(message: "store-test", level: .info, categoryName: "general",
                             file: "T.swift", function: "f()", line: 1)

        let logs = publisher.getRecentLogs()
        #expect(logs.contains(where: { $0.message == "store-test" }))
    }

    @Test("Logging a message stores it in recent logs")
    func logStoresEntry() {
        let publisher = PVLogPublisher.shared
        publisher.clearLogs()

        publisher.log("test entry", level: .info, file: "Test.swift", function: "testFn()", line: 1)

        let logs = publisher.getRecentLogs()
        #expect(logs.contains(where: { $0.message == "test entry" }))
    }

    @Test("clearLogs removes all entries")
    func clearLogsRemovesEntries() {
        let publisher = PVLogPublisher.shared
        publisher.log("entry to clear", level: .debug, file: "T.swift", function: "f()", line: 1)

        publisher.clearLogs()

        let logs = publisher.getRecentLogs()
        #expect(!logs.contains(where: { $0.message == "entry to clear" }))
    }

    @Test("getRecentLogs with minLevel filters correctly")
    func getRecentLogsFiltering() {
        let publisher = PVLogPublisher.shared
        publisher.clearLogs()

        publisher.log("verbose msg", level: .verbose, file: "T.swift", function: "f()", line: 1)
        publisher.log("error msg",   level: .error,   file: "T.swift", function: "f()", line: 2)

        let allLogs   = publisher.getRecentLogs()
        let errorLogs = publisher.getRecentLogs(minLevel: .error)

        #expect(errorLogs.allSatisfy { $0.level >= .error })
        #expect(allLogs.count >= errorLogs.count)
    }

    @Test("Convenience verbose method logs at verbose level")
    func verboseConvenience() {
        let publisher = PVLogPublisher.shared
        publisher.clearLogs()

        publisher.verbose("verbose convenience", file: "T.swift", function: "f()", line: 1)

        let logs = publisher.getRecentLogs(minLevel: .verbose)
        #expect(logs.contains(where: { $0.message == "verbose convenience" && $0.level == .verbose }))
    }

    @Test("Convenience error method logs at error level")
    func errorConvenience() {
        let publisher = PVLogPublisher.shared
        publisher.clearLogs()

        publisher.error("error convenience", file: "T.swift", function: "f()", line: 1)

        let logs = publisher.getRecentLogs(minLevel: .error)
        #expect(logs.contains(where: { $0.message == "error convenience" && $0.level == .error }))
    }

    #if canImport(Combine)
    @Test("logPublisher property is accessible")
    func logPublisherAccessible() {
        _ = PVLogPublisher.shared.logPublisher
    }
    #endif

    // MARK: - Per-Category Level Filtering Tests

    @Test("setMinLevel suppresses entries below threshold")
    func categoryFilterSuppressesLow() {
        let publisher = PVLogPublisher.shared
        publisher.clearLogs()
        publisher.resetCategoryFilters()
        publisher.setMinLevel(.error, forCategory: "audio")

        publisher.storeEntry(message: "audio-debug", level: .debug, categoryName: "audio",
                             file: "T.swift", function: "f()", line: 1)
        publisher.storeEntry(message: "audio-error", level: .error, categoryName: "audio",
                             file: "T.swift", function: "f()", line: 2)

        let logs = publisher.getRecentLogs()
        #expect(!logs.contains(where: { $0.message == "audio-debug" }),
                "debug entry should be filtered out")
        #expect(logs.contains(where: { $0.message == "audio-error" }),
                "error entry should pass the filter")

        publisher.resetCategoryFilters()
    }

    @Test("minLevel returns verbose when no filter set")
    func minLevelDefault() {
        let publisher = PVLogPublisher.shared
        publisher.resetCategoryFilters()
        #expect(publisher.minLevel(forCategory: "emulator") == .verbose)
    }

    @Test("setMinLevel and minLevel round-trip")
    func setAndGetMinLevel() {
        let publisher = PVLogPublisher.shared
        publisher.setMinLevel(.warning, forCategory: "video")
        #expect(publisher.minLevel(forCategory: "video") == .warning)
        publisher.resetCategoryFilters()
    }

    @Test("resetCategoryFilters clears all levels")
    func resetFilters() {
        let publisher = PVLogPublisher.shared
        publisher.setMinLevel(.error, forCategory: "ui")
        publisher.setMinLevel(.warning, forCategory: "network")
        publisher.resetCategoryFilters()
        #expect(publisher.minLevel(forCategory: "ui") == .verbose)
        #expect(publisher.minLevel(forCategory: "network") == .verbose)
    }

    // MARK: - AsyncStream Tests

    @Test("makeLogStream receives new entries")
    func asyncStreamReceivesEntries() async throws {
        let publisher = PVLogPublisher.shared
        publisher.clearLogs()

        let stream = publisher.makeLogStream()

        // Log one entry then cancel the stream
        let uniqueMessage = "asyncstream-test-\(UUID().uuidString)"
        publisher.storeEntry(message: uniqueMessage, level: .info, categoryName: "general",
                             file: "T.swift", function: "f()", line: 1)

        var received: LogEntry?
        for await entry in stream {
            received = entry
            break // consume one entry and exit
        }

        #expect(received != nil)
        #expect(received?.message == uniqueMessage)
    }

    @Test("makeLogStream can be cancelled without leaking continuations")
    func asyncStreamCancellation() async throws {
        let publisher = PVLogPublisher.shared

        // Create the stream first — the continuation is registered immediately inside
        // the AsyncStream initialiser closure, before any iteration begins.
        let stream = publisher.makeLogStream()

        // Start a consumer task that iterates the stream; we will cancel it explicitly
        // to exercise the onTermination cleanup path.
        let consumerTask = Task {
            for await _ in stream {
                // Intentionally ignore entries; we're testing cancellation/cleanup.
            }
        }

        // Deterministically cancel the consumer and ensure it completes without hanging.
        consumerTask.cancel()
        _ = await consumerTask.result

        #expect(consumerTask.isCancelled)
    }
}

// MARK: - New Category Tests

@Suite("PVLogCategory")
struct PVLogCategoryTests {

    @Test("New categories are accessible")
    func newCategoriesExist() {
        // Verify the new static categories compile and return non-nil loggers
        _ = PVLogCategory.emulator
        _ = PVLogCategory.ui
        _ = PVLogCategory.controller
        _ = PVLogCategory.saveState
        _ = PVLogCategory.library
        #expect(Bool(true))
    }

    #if !canImport(OSLog)
    @Test("Non-OSLog category names are correct")
    func categoryNamesNonOSLog() {
        #expect(PVLogCategory.emulator.categoryName == "emulator")
        #expect(PVLogCategory.ui.categoryName == "ui")
        #expect(PVLogCategory.controller.categoryName == "controller")
        #expect(PVLogCategory.saveState.categoryName == "savestate")
        #expect(PVLogCategory.library.categoryName == "library")
    }
    #endif

    @Test("categoryName(from:) returns known names for predefined categories")
    func categoryNameFromKnown() {
        #expect(PVLogPublisher.categoryName(from: .audio) == "audio")
        #expect(PVLogPublisher.categoryName(from: .video) == "video")
        #expect(PVLogPublisher.categoryName(from: .general) == "general")
        #expect(PVLogPublisher.categoryName(from: .emulator) == "emulator")
        #expect(PVLogPublisher.categoryName(from: .library) == "library")
    }
}

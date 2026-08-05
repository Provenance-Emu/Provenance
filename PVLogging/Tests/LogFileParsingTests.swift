//
//  LogFileParsingTests.swift
//  PVLoggingTests
//
//  Covers the log-file parsing used when importing a previously exported log
//  back into the viewer (#3612).
//
import Testing
import Foundation
@testable import PVLogging

struct LogFileParsingLevelTests {

    @Test("Each exporter level tag is recognised")
    func parsesEveryLevelTag() {
        #expect(LogFileParsing.level(in: "[12:00:00.000] [ERROR] boom") == .error)
        #expect(LogFileParsing.level(in: "[12:00:00.000] [WARNING] careful") == .warning)
        #expect(LogFileParsing.level(in: "[12:00:00.000] [INFO] hello") == .info)
        #expect(LogFileParsing.level(in: "[12:00:00.000] [DEBUG] details") == .debug)
        #expect(LogFileParsing.level(in: "[12:00:00.000] [VERBOSE] noise") == .verbose)
    }

    @Test("Untagged lines report no level rather than guessing")
    func untaggedLineHasNoLevel() {
        #expect(LogFileParsing.level(in: "just a bare line") == nil)
        #expect(LogFileParsing.level(in: "") == nil)
    }

    @Test("Level tags are matched case-insensitively")
    func levelTagIsCaseInsensitive() {
        #expect(LogFileParsing.level(in: "[error] lowercase tag") == .error)
        #expect(LogFileParsing.level(in: "[Warning] mixed case") == .warning)
    }

    @Test("A bare level word without brackets is not treated as a tag")
    func requiresBracketedTag() {
        #expect(LogFileParsing.level(in: "this line mentions ERROR in prose") == nil)
    }

    @Test("The more severe tag wins when a message quotes another level")
    func moreSevereTagWins() {
        // Checks run most-severe first, so an error line whose message quotes
        // "[INFO]" stays an error regardless of tag order in the text.
        #expect(LogFileParsing.level(in: "[ERROR] failed to handle [INFO] record") == .error)
        #expect(LogFileParsing.level(in: "[INFO] retrying after [ERROR] earlier") == .error)
    }
}

struct LogFileParsingLineTests {

    @Test("Lines are split in order with zero-based ids")
    func parsesLinesInOrder() {
        let parsed = LogFileParsing.parseLines("alpha\nbravo\ncharlie")

        #expect(parsed.count == 3)
        #expect(parsed.map(\.id) == [0, 1, 2])
        #expect(parsed.map(\.text) == ["alpha", "bravo", "charlie"])
    }

    @Test("Line ids are unique so they can drive ForEach identity")
    func lineIDsAreUnique() {
        // Deliberately repeated text — identity must come from position.
        let parsed = LogFileParsing.parseLines("same\nsame\nsame")

        #expect(Set(parsed.map(\.id)).count == parsed.count)
    }

    @Test("Blank lines are preserved so exported spacing survives a round trip")
    func preservesBlankLines() {
        let parsed = LogFileParsing.parseLines("header\n\nbody")

        #expect(parsed.count == 3)
        #expect(parsed[1].text.isEmpty)
    }

    @Test("Empty input yields a single empty line, not a crash")
    func handlesEmptyInput() {
        let parsed = LogFileParsing.parseLines("")

        #expect(parsed.count == 1)
        #expect(parsed[0].text.isEmpty)
        #expect(parsed[0].level == nil)
    }

    @Test("Levels are attached to the lines that carry them")
    func attachesLevelsPerLine() {
        let parsed = LogFileParsing.parseLines("""
        [ERROR] first
        untagged second
        [INFO] third
        """)

        #expect(parsed.map(\.level) == [.error, nil, .info])
    }

    @Test("Windows line endings split into separate lines")
    func handlesCarriageReturns() {
        let parsed = LogFileParsing.parseLines("one\r\ntwo")

        // `.newlines` treats CRLF as a single break rather than emitting a blank.
        #expect(parsed.map(\.text) == ["one", "two"])
    }
}

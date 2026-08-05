//
//  LogFileParsing.swift
//  PVLogging
//
//  Parsing helpers for reading previously-exported log files back in.
//  Lives here rather than in the UI layer so it is testable without a
//  full workspace build — PVLogging builds and tests standalone.
//

import Foundation

/// Parses plain-text log files produced by Provenance's log exporter (or any
/// log whose lines carry a `[LEVEL]` tag) back into structured lines.
public enum LogFileParsing {

    /// A single parsed line of a log file.
    public struct ParsedLine: Identifiable, Equatable, Sendable {
        /// Zero-based index of the line within the file. Stable and unique,
        /// which makes it usable directly as a SwiftUI `ForEach` identity.
        public let id: Int
        /// The raw line text, unmodified.
        public let text: String
        /// Level parsed from a `[LEVEL]` tag, or `nil` when the line carries none.
        public let level: LogLevel?

        public init(id: Int, text: String, level: LogLevel?) {
            self.id = id
            self.text = text
            self.level = level
        }
    }

    /// Splits `text` into parsed lines, preserving order and blank lines.
    ///
    /// CRLF is normalised first: `.newlines` is a character set, so it would
    /// otherwise treat `\r\n` as two breaks and insert a spurious blank line
    /// between every line of a Windows-generated log.
    /// - Parameter text: Full contents of a log file.
    /// - Returns: One `ParsedLine` per line, indexed from zero.
    public static func parseLines(_ text: String) -> [ParsedLine] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .enumerated()
            .map { ParsedLine(id: $0.offset, text: $0.element, level: level(in: $0.element)) }
    }

    /// Best-effort parse of a `[LEVEL]` tag from a single log line.
    ///
    /// Matches the uppercase tag emitted by the exporter (`[ERROR]`, `[WARNING]`,
    /// `[INFO]`, `[DEBUG]`, `[VERBOSE]`). Returns `nil` for untagged lines so
    /// callers can render them neutrally rather than guessing.
    public static func level(in line: String) -> LogLevel? {
        let upper = line.uppercased()
        if upper.contains("[ERROR]") { return .error }
        if upper.contains("[WARNING]") { return .warning }
        if upper.contains("[INFO]") { return .info }
        if upper.contains("[DEBUG]") { return .debug }
        if upper.contains("[VERBOSE]") { return .verbose }
        return nil
    }
}

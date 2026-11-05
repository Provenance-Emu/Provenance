//
//  RetroLogViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import PVLogging
import ZIPFoundation

/// ViewModel for RetroLogView
public final class RetroLogViewModel: ObservableObject {
    // MARK: - Sort Order Enum
    public enum SortOrder {
        case newestFirst
        case oldestFirst
    }

    // MARK: - Published Properties

    /// The raw logs, typically appended chronologically
    @Published public var logs: [LogEntry] = []

    /// The minimum log level to display
    @Published public var minLogLevel: LogLevel = .info

    /// Whether to auto-scroll to the bottom
    @Published public var autoScroll = true

    /// Whether to show full log details
    @Published public var showFullDetails = false

    /// Search text
    @Published public var searchText = ""

    /// Current sort order for logs
    @Published public var sortOrder: SortOrder = .newestFirst

    /// A log session imported from a file, shown in place of the live logs.
    /// `nil` means the live session is being displayed.
    @Published public var importedSession: ImportedLogSession?

    // MARK: - Private Properties

    /// Subscription to log publisher
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(exportService: LogExportService = LogExportService(outputDirectory: RetroLogViewModel.defaultExportDirectory)) {
        self.exportService = exportService

        // Load initial logs
        logs = PVLogPublisher.shared.getRecentLogs(minLevel: minLogLevel)

        // Subscribe to log updates
        PVLogPublisher.shared.logPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] entry in
                self?.logs.append(entry)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Clear all logs
    public func clearLogs() {
        logs.removeAll()
        PVLogPublisher.shared.clearLogs()
    }

// `UIPasteboard` is UIKit-only, but PVUIBase also declares native macOS and
// watchOS support where UIKit doesn't exist, so gate on the framework rather
// than just excluding tvOS.
#if !os(tvOS) && canImport(UIKit)
    /// Copies whatever is currently on screen to the clipboard — the imported
    /// session when one is open, otherwise the filtered live logs.
    public func copyFilteredLogsToClipboard() {
        if importedSession != nil {
            let lines = displayedImportedLines
            guard !lines.isEmpty else { return }
            UIPasteboard.general.string = lines.map(\.text).joined(separator: "\n")
            return
        }

        guard !displayedLogs.isEmpty else { return }

        let logTexts = displayedLogs.map { log -> String in
            var entryText = "[\(log.formattedTimestamp)] [\(log.level.name.uppercased())] "
            if !log.category.isEmpty {
                entryText += "(\(log.category)) "
            }
            if self.showFullDetails {
                let fileName = (log.file as NSString).lastPathComponent
                entryText += "[\(fileName):\(log.line)] "
            }
            entryText += log.message
            return entryText
        }

        UIPasteboard.general.string = logTexts.joined(separator: "\n\n")
    }
#endif

    /// Toggle the sort order of logs.
    public func toggleSortOrder() {
        sortOrder = (sortOrder == .newestFirst) ? .oldestFirst : .newestFirst
    }

    /// Get color for log level
    public func logLevelColor(_ level: LogLevel) -> Color {
        switch level {
        case .verbose:
            return Color.gray
        case .debug:
            return RetroTheme.retroBlue
        case .info:
            return Color.green
        case .warning:
            return Color.orange
        case .error:
            return RetroTheme.retroPink
        }
    }

    /// Get filtered and sorted logs based on search text, minimum log level, and sort order.
    public var displayedLogs: [LogEntry] {
        let filtered = logs.filter { log in
            (searchText.isEmpty || log.message.localizedCaseInsensitiveContains(searchText)) &&
            log.level >= minLogLevel
        }

        switch sortOrder {
        case .newestFirst:
            return filtered.reversed()
        case .oldestFirst:
            return filtered
        }
    }

    // MARK: - Export

    /// Builds exports. Packaging, header rendering and source enumeration live in
    /// `PVLogging.LogExportService` so they are unit-tested without a workspace build.
    public let exportService: LogExportService

    /// Exports older than this are swept from the output folder before a new one is written.
    private static let staleExportAge: TimeInterval = 24 * 60 * 60

    /// Where exports land. iOS shares them through the system share sheet, so the temp
    /// folder is fine; tvOS has no share sheet, so they go under the WebDAV browse root
    /// (`Caches`, see `PVModernWebServer`) where a computer on the LAN can pick them up.
    static var defaultExportDirectory: URL {
#if os(tvOS)
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return caches.appendingPathComponent("Logs/Exports", isDirectory: true)
        }
#endif
        return LogExportService.defaultOutputDirectory
    }

    /// Files on disk the exporter can include, re-read on every access.
    public var availableExportSources: LogExportSourceSet {
        exportService.availableSources()
    }

    /// Writes an export of the displayed logs plus whatever `options` selects.
    ///
    /// `includeSourceLocation` follows the viewer's detail toggle unless the caller sets it.
    /// Must be called from the main actor to safely read `displayedLogs`.
    @MainActor
    public func exportLogs(options: LogExportOptions) throws -> LogExportResult {
        var resolved = options
        if !resolved.includeSourceLocation { resolved.includeSourceLocation = showFullDetails }
        exportService.removeExports(olderThan: Self.staleExportAge)
        return try exportService.export(entries: displayedLogs, totalEntryCount: logs.count, options: resolved)
    }

    // MARK: - Log files

    /// Session log files written by `PVLogFileManager`, newest first.
    public func sessionLogFiles() -> [LogExportFile] {
        availableExportSources.sessionFiles
    }

    /// True while `url` is the session file being written; it can be viewed but not deleted.
    public func isActiveSessionFile(_ url: URL) -> Bool {
        PVLogFileManager.shared.isActiveSessionFile(url)
    }

    /// Deletes a session log file. Throws `PVLogFileManager.DeleteError.activeSessionFile`
    /// for the file currently being written.
    public func deleteSessionLogFile(at url: URL) throws {
        try PVLogFileManager.shared.deleteFile(at: url)
        if importedSession?.sourceURL == url {
            closeImportedSession()
        }
    }

    // MARK: - Import

    /// A single line of an imported log file.
    /// The parsing itself lives in `PVLogging.LogFileParsing` so it can be
    /// unit-tested without a full workspace build.
    public typealias ImportedLogLine = LogFileParsing.ParsedLine

    /// A log session read from a file, displayed instead of the live session.
    public struct ImportedLogSession: Equatable {
        /// File name the session was read from, shown in the banner.
        public let name: String
        public let lines: [ImportedLogLine]
        /// Where the session was read from, so deleting that file can close the view.
        public let sourceURL: URL?

        public init(name: String, lines: [ImportedLogLine], sourceURL: URL? = nil) {
            self.name = name
            self.lines = lines
            self.sourceURL = sourceURL
        }
    }

    /// Errors surfaced to the user when importing a log file fails.
    public enum LogImportError: LocalizedError {
        case unreadable
        case noLogsInArchive
        case tooLarge

        public var errorDescription: String? {
            switch self {
            case .unreadable:
                return "That file could not be read as text."
            case .noLogsInArchive:
                return "No log files were found inside that archive."
            case .tooLarge:
                return "That log is too large to open (limit \(RetroLogViewModel.maxImportBytes / 1_048_576) MB)."
            }
        }
    }

    /// Upper bound on how much log text will be read into memory.
    ///
    /// The file is user-chosen, but a very large log — or a highly compressed
    /// archive — would otherwise be expanded unbounded into `Data`, `String`,
    /// and finally an array of line objects.
    public static let maxImportBytes = 64 * 1_048_576  // 64 MB

    /// Reads a log file (plain text or an exported `.zip` bundle) and displays it
    /// in place of the live logs.
    ///
    /// File I/O, ZIP extraction and parsing all run off the main actor; only the
    /// final publish of `importedSession` hops back, so importing a large log
    /// never blocks rendering or input.
    @MainActor
    public func importLog(from url: URL) async throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent
        let isArchive = url.pathExtension.lowercased() == "zip"

        let lines = try await Task.detached(priority: .userInitiated) { () throws -> [ImportedLogLine] in
            let text = isArchive
                ? try Self.text(fromArchiveAt: url)
                : try Self.text(fromPlainFileAt: url)
            return LogFileParsing.parseLines(text)
        }.value

        importedSession = ImportedLogSession(name: name, lines: lines, sourceURL: url)
    }

    /// Reads a plain-text log, refusing anything past `maxImportBytes`.
    private static func text(fromPlainFileAt url: URL) throws -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maxImportBytes else { throw LogImportError.tooLarge }
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            throw LogImportError.unreadable
        }
        return contents
    }

    /// Returns to the live log session.
    public func closeImportedSession() {
        importedSession = nil
    }

    /// Whether there is nothing on screen to copy — accounts for an open import.
    public var copyableLinesAreEmpty: Bool {
        importedSession != nil ? displayedImportedLines.isEmpty : displayedLogs.isEmpty
    }

    /// Imported lines after applying the current search filter.
    public var displayedImportedLines: [ImportedLogLine] {
        guard let session = importedSession else { return [] }
        guard !searchText.isEmpty else { return session.lines }
        return session.lines.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    /// Concatenates every text log found inside an exported ZIP bundle.
    private static func text(fromArchiveAt url: URL) throws -> String {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw LogImportError.unreadable
        }

        /// `device_info.txt` first so the header reads at the top, then the rest alphabetically.
        /// JSON covers `manifest.json` and the MetricKit crash payloads a bundle may carry.
        let textEntries = archive
            .filter { ["txt", "log", "json"].contains(($0.path as NSString).pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                if lhs.path.hasSuffix("device_info.txt") != rhs.path.hasSuffix("device_info.txt") {
                    return lhs.path.hasSuffix("device_info.txt")
                }
                return lhs.path < rhs.path
            }

        guard !textEntries.isEmpty else { throw LogImportError.noLogsInArchive }

        var sections: [String] = []
        var budget = maxImportBytes
        for entry in textEntries {
            // Check the declared size before extracting so a highly-compressed
            // entry can't expand past the budget on its way into memory.
            // `uncompressedSize` is UInt64; compare in that domain.
            guard entry.uncompressedSize <= UInt64(budget) else { throw LogImportError.tooLarge }
            var data = Data()
            guard (try? archive.extract(entry, consumer: { data.append($0) })) != nil,
                  let contents = String(data: data, encoding: .utf8) else { continue }
            budget -= min(budget, data.count)
            sections.append("=== \(entry.path) ===\n\(contents)")
        }

        guard !sections.isEmpty else { throw LogImportError.noLogsInArchive }
        return sections.joined(separator: "\n\n")
    }
}

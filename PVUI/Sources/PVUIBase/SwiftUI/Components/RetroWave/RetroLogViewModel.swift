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

    public init() {
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

#if !os(tvOS)
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

    /// Options controlling what to include in a log export.
    public struct LogExportOptions {
        public var includeAppLogs: Bool
        public var includeDeviceInfo: Bool
        public var includeRetroArchLogs: Bool

        public init(includeAppLogs: Bool = true, includeDeviceInfo: Bool = true, includeRetroArchLogs: Bool = true) {
            self.includeAppLogs = includeAppLogs
            self.includeDeviceInfo = includeDeviceInfo
            self.includeRetroArchLogs = includeRetroArchLogs
        }
    }

    /// Returns the RetroArch logs directory URL, or nil if it doesn't exist on disk.
    public var retroArchLogsDirectory: URL? {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docDir.appendingPathComponent("RetroArch/logs")
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }

    /// Builds a device/app info header string.
    @MainActor
    private func buildDeviceInfo() -> String {
        var info = "=== Provenance Log Export ===\n"
        info += "Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .long))\n"
        let bundle = Bundle.main
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            info += "App Version: \(version) (\(build))\n"
        }
#if os(iOS)
        info += "Device: \(UIDevice.current.model)\n"
        info += "OS: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n"
#elseif os(tvOS)
        info += "Platform: tvOS\n"
#elseif targetEnvironment(macCatalyst)
        info += "Platform: macOS (Catalyst)\n"
#endif
        info += "Displayed Log Count: \(displayedLogs.count) (total in session: \(logs.count))\n"
        return info
    }

    /// Formats a single log entry as plain text.
    private func formatEntry(_ log: LogEntry) -> String {
        var text = "[\(log.formattedTimestamp)] [\(log.level.name.uppercased())]"
        if !log.category.isEmpty { text += " (\(log.category))" }
        if showFullDetails {
            let fileName = (log.file as NSString).lastPathComponent
            text += " [\(fileName):\(log.line)]"
        }
        text += " \(log.message)"
        return text
    }

    /// Exports the currently displayed logs as a plain-text file in the temp directory.
    /// - Returns: URL of the created `.txt` file, or `nil` on failure.
    /// Must be called from the main actor to safely read `displayedLogs`.
    @MainActor
    public func exportLogsAsText(options: LogExportOptions = .init()) -> URL? {
        var content = ""
        if options.includeDeviceInfo {
            content += buildDeviceInfo() + "\n\n"
        }
        if options.includeAppLogs && !displayedLogs.isEmpty {
            content += "=== App Logs ===\n"
            content += displayedLogs.map { formatEntry($0) }.joined(separator: "\n")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "provenance_logs_\(formatter.string(from: Date())).txt"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Exports logs and optional RetroArch logs as a ZIP bundle in the temp directory.
    /// - Returns: URL of the created `.zip` file, or `nil` on failure.
    /// Must be called from the main actor to safely read `displayedLogs`.
    @MainActor
    public func exportLogsAsZip(options: LogExportOptions = .init()) -> URL? {
        let fm = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let tempDir = fm.temporaryDirectory.appendingPathComponent("pv_log_export_\(timestamp)")
        let zipURL = fm.temporaryDirectory.appendingPathComponent("provenance_logs_\(timestamp).zip")

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

            if options.includeDeviceInfo {
                let infoURL = tempDir.appendingPathComponent("device_info.txt")
                try buildDeviceInfo().write(to: infoURL, atomically: true, encoding: .utf8)
            }

            if options.includeAppLogs {
                let logsText = displayedLogs.map { formatEntry($0) }.joined(separator: "\n")
                let logsURL = tempDir.appendingPathComponent("app_logs.txt")
                try logsText.write(to: logsURL, atomically: true, encoding: .utf8)
            }

            if options.includeRetroArchLogs, let raDir = retroArchLogsDirectory {
                let destRADir = tempDir.appendingPathComponent("retroarch_logs")
                try fm.copyItem(at: raDir, to: destRADir)
            }

            try fm.zipDirectory(at: tempDir, to: zipURL)
            try? fm.removeItem(at: tempDir)
            return zipURL
        } catch {
            try? fm.removeItem(at: tempDir)
            return nil
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
    }

    /// Errors surfaced to the user when importing a log file fails.
    public enum LogImportError: LocalizedError {
        case unreadable
        case noLogsInArchive

        public var errorDescription: String? {
            switch self {
            case .unreadable:
                return "That file could not be read as text."
            case .noLogsInArchive:
                return "No log files were found inside that archive."
            }
        }
    }

    /// Reads a log file (plain text or an exported `.zip` bundle) and displays it
    /// in place of the live logs.
    /// Main-actor bound because it publishes `importedSession`.
    @MainActor
    public func importLog(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let text: String
        if url.pathExtension.lowercased() == "zip" {
            text = try Self.text(fromArchiveAt: url)
        } else {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
                throw LogImportError.unreadable
            }
            text = contents
        }

        let lines = LogFileParsing.parseLines(text)

        importedSession = ImportedLogSession(name: url.lastPathComponent, lines: lines)
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
        let textEntries = archive
            .filter { ["txt", "log"].contains(($0.path as NSString).pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                if lhs.path.hasSuffix("device_info.txt") != rhs.path.hasSuffix("device_info.txt") {
                    return lhs.path.hasSuffix("device_info.txt")
                }
                return lhs.path < rhs.path
            }

        guard !textEntries.isEmpty else { throw LogImportError.noLogsInArchive }

        var sections: [String] = []
        for entry in textEntries {
            var data = Data()
            guard (try? archive.extract(entry, consumer: { data.append($0) })) != nil,
                  let contents = String(data: data, encoding: .utf8) else { continue }
            sections.append("=== \(entry.path) ===\n\(contents)")
        }

        guard !sections.isEmpty else { throw LogImportError.noLogsInArchive }
        return sections.joined(separator: "\n\n")
    }
}

// MARK: - FileManager + Simple Zip

private extension FileManager {
    /// Creates a ZIP archive at `destination` containing all files in `directory`.
    /// Uses Foundation's built-in zip coordination (macOS/iOS 13+).
    func zipDirectory(at directory: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinatorError) { zippedURL in
            do {
                try self.copyItem(at: zippedURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError { throw error }
        if let error = copyError { throw error }
    }
}

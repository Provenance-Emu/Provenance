//
//  LogExportService.swift
//  PVLogging
//
//  Packages the in-memory log session, rotated session files, crash reports and
//  core logs into a single text file or a zip bundle for sharing (#3612).
//

import Foundation

// MARK: - Manifest

/// The Provenance log manifest inside a zip export: what was included and where it came from.
public struct LogExportManifest: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        /// Path inside the bundle, relative to its root folder.
        public let path: String
        public let kind: String
        public let size: Int64
        public let modificationDate: Date?
        /// Original on-device path, for reports that mention a specific file.
        public let sourcePath: String?

        public init(path: String, kind: String, size: Int64, modificationDate: Date?, sourcePath: String?) {
            self.path = path
            self.kind = kind
            self.size = size
            self.modificationDate = modificationDate
            self.sourcePath = sourcePath
        }
    }

    public static let currentVersion = 1

    public let version: Int
    public let header: LogExportHeader
    public let files: [Entry]

    public init(version: Int = LogExportManifest.currentVersion, header: LogExportHeader, files: [Entry]) {
        self.version = version
        self.header = header
        self.files = files
    }

    /// Bundle entry kinds that are not a `LogExportFile.Kind`.
    public static let deviceInfoKind = "device-info"
    public static let appLogsKind = "app-logs"

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Result & errors

/// A finished export.
public struct LogExportResult: Equatable, Sendable {
    public let url: URL
    public let format: LogExportOptions.Format
    /// Relative paths of everything written (bundle entries, or the sections of a text export).
    public let includedPaths: [String]

    public init(url: URL, format: LogExportOptions.Format, includedPaths: [String]) {
        self.url = url
        self.format = format
        self.includedPaths = includedPaths
    }
}

public enum LogExportError: LocalizedError, Equatable {
    /// Every include toggle was off.
    case nothingSelected
    /// Zip packaging is not available on this platform.
    case zipUnsupported
    /// The archive step failed; the associated text is the underlying description.
    case archiveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .nothingSelected: return "Nothing was selected to export."
        case .zipUnsupported: return "Zip export is not supported on this platform."
        case .archiveFailed(let reason): return "Could not create the export archive: \(reason)"
        }
    }
}

// MARK: - Service

/// Builds log exports. Stateless apart from its configured locations and output folder.
public struct LogExportService: Sendable {
    /// Directories scanned for files to include.
    public let locations: LogExportLocations
    /// Where finished exports are written.
    public let outputDirectory: URL
    /// `FileManager` is not `Sendable`, so the shared instance is resolved per use.
    private var fileManager: FileManager { .default }

    /// Files larger than this are truncated when inlined into a text export; a zip copies them whole.
    public static let maxInlinedBytes = 8 * 1_048_576

    /// Default output folder: a dedicated subfolder of the temp directory.
    public static var defaultOutputDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ProvenanceLogExports", isDirectory: true)
    }

    public init(locations: LogExportLocations = .default,
                outputDirectory: URL = LogExportService.defaultOutputDirectory) {
        self.locations = locations
        self.outputDirectory = outputDirectory
    }

    /// What is on disk right now.
    public func availableSources() -> LogExportSourceSet {
        LogExportSourceSet.scan(locations)
    }

    // MARK: Entry formatting

    /// One line per entry, matching the format `PVLogFileManager` writes and `LogFileParsing` reads.
    public static func format(_ entry: LogEntry, includeSourceLocation: Bool) -> String {
        var text = "[\(entry.formattedTimestamp)] [\(entry.level.name.uppercased())]"
        if !entry.category.isEmpty { text += " (\(entry.category))" }
        if includeSourceLocation {
            let fileName = (entry.file as NSString).lastPathComponent
            text += " [\(fileName):\(entry.line)]"
        }
        text += " \(entry.message)"
        return text
    }

    // MARK: Export

    /// Writes an export and returns where it landed.
    /// - Parameters:
    ///   - entries: the in-memory entries to include (already filtered by the caller).
    ///   - totalEntryCount: size of the whole in-memory session, for the header.
    ///   - options: what to include and the output format.
    ///   - header: override for tests; defaults to the running app's metadata.
    ///   - date: timestamp used for the file name and header.
    public func export(entries: [LogEntry],
                       totalEntryCount: Int? = nil,
                       options: LogExportOptions,
                       header: LogExportHeader? = nil,
                       date: Date = Date()) throws -> LogExportResult {
        guard !options.isEmpty else { throw LogExportError.nothingSelected }

        let resolvedHeader = header ?? LogExportHeader.current(
            options: options,
            entryCount: entries.count,
            totalEntryCount: totalEntryCount ?? entries.count,
            date: date
        )
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let baseName = Self.baseName(for: date)

        switch options.format {
        case .text:
            let url = outputDirectory.appendingPathComponent("\(baseName).\(options.format.fileExtension)")
            let rendered = renderText(entries: entries, options: options, header: resolvedHeader)
            try rendered.text.write(to: url, atomically: true, encoding: .utf8)
            return LogExportResult(url: url, format: .text, includedPaths: rendered.sections)

        case .zip:
            let staged = try stage(entries: entries, options: options, header: resolvedHeader, baseName: baseName)
            defer { try? fileManager.removeItem(at: staged.directory) }
            let url = outputDirectory.appendingPathComponent("\(baseName).\(options.format.fileExtension)")
            try? fileManager.removeItem(at: url)
            try zip(directory: staged.directory, to: url)
            return LogExportResult(url: url, format: .zip, includedPaths: staged.manifest.files.map(\.path))
        }
    }

    /// `provenance_logs_YYYY-MM-DD_HH-mm-ss`
    static func baseName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "provenance_logs_\(formatter.string(from: date))"
    }

    // MARK: Text

    struct RenderedText {
        let text: String
        let sections: [String]
    }

    /// Header, then each selected source under a `=== Title ===` banner.
    func renderText(entries: [LogEntry], options: LogExportOptions, header: LogExportHeader) -> RenderedText {
        var parts: [String] = []
        var sections: [String] = []

        if options.includeDeviceInfo {
            parts.append(header.render())
            sections.append(LogExportManifest.deviceInfoKind)
        }
        if options.includeAppLogs {
            let body = entries.map { Self.format($0, includeSourceLocation: options.includeSourceLocation) }
            parts.append(IncomingLogFile.appLogsHeader + "\n" + body.joined(separator: "\n") + "\n")
            sections.append(LogExportManifest.appLogsKind)
        }

        let sources = availableSources()
        for file in selectedFiles(from: sources, options: options) {
            parts.append("=== \(Self.sectionTitle(for: file.kind)): \(file.name) ===\n" + inlinedContents(of: file) + "\n")
            sections.append("\(file.kind.rawValue)/\(file.name)")
        }

        return RenderedText(text: parts.joined(separator: "\n"), sections: sections)
    }

    static func sectionTitle(for kind: LogExportFile.Kind) -> String {
        switch kind {
        case .session: return "Session Log"
        case .crash: return "Crash Report"
        case .core: return "Core Log"
        }
    }

    /// UTF-8 contents, truncated past `maxInlinedBytes`; a note stands in for unreadable files.
    private func inlinedContents(of file: LogExportFile) -> String {
        guard let handle = try? FileHandle(forReadingFrom: file.url) else {
            return "(unreadable)"
        }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: Self.maxInlinedBytes)) ?? Data()
        guard let text = String(data: data, encoding: .utf8) else {
            return "(skipped: not UTF-8 text, \(file.size) bytes)"
        }
        if file.size > Int64(Self.maxInlinedBytes) {
            return text + "\n(truncated after \(Self.maxInlinedBytes) of \(file.size) bytes)"
        }
        return text
    }

    // MARK: Zip

    struct StagedBundle {
        let directory: URL
        let manifest: LogExportManifest
    }

    /// Lays the bundle out in a temp folder named `baseName`, ready to be zipped.
    func stage(entries: [LogEntry],
               options: LogExportOptions,
               header: LogExportHeader,
               baseName: String) throws -> StagedBundle {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("ProvenanceLogExportStaging-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(baseName, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        var manifestEntries: [LogExportManifest.Entry] = []

        if options.includeDeviceInfo {
            let path = IncomingLogFile.bundleDeviceInfoName
            let text = header.render()
            try text.write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
            manifestEntries.append(.init(path: path, kind: LogExportManifest.deviceInfoKind,
                                         size: Int64(text.utf8.count), modificationDate: header.exportDate, sourcePath: nil))
        }

        if options.includeAppLogs {
            let path = IncomingLogFile.bundleAppLogsName
            let text = entries
                .map { Self.format($0, includeSourceLocation: options.includeSourceLocation) }
                .joined(separator: "\n") + "\n"
            try text.write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
            manifestEntries.append(.init(path: path, kind: LogExportManifest.appLogsKind,
                                         size: Int64(text.utf8.count), modificationDate: header.exportDate, sourcePath: nil))
        }

        let sources = availableSources()
        for file in selectedFiles(from: sources, options: options) {
            let folder = Self.bundleFolder(for: file.kind)
            let relative = Self.relativePath(of: file, in: locations)
            let destination = root.appendingPathComponent(folder, isDirectory: true).appendingPathComponent(relative)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            // The current session file is open for writing; copying still captures what has been flushed.
            try fileManager.copyItem(at: file.url, to: destination)
            manifestEntries.append(.init(path: "\(folder)/\(relative)", kind: file.kind.rawValue,
                                         size: file.size, modificationDate: file.modificationDate, sourcePath: file.url.path))
        }

        let manifest = LogExportManifest(header: header, files: manifestEntries)
        let data = try LogExportManifest.encoder().encode(manifest)
        try data.write(to: root.appendingPathComponent(IncomingLogFile.bundleManifestName), options: .atomic)
        return StagedBundle(directory: root, manifest: manifest)
    }

    static func bundleFolder(for kind: LogExportFile.Kind) -> String {
        switch kind {
        case .session: return "session_logs"
        case .crash: return "crash_reports"
        case .core: return "core_logs"
        }
    }

    /// Path of `file` below its source directory, so nested core logs keep their layout.
    static func relativePath(of file: LogExportFile, in locations: LogExportLocations) -> String {
        let base: URL
        switch file.kind {
        case .session: base = locations.sessionLogsDirectory
        case .crash: base = locations.crashReportsDirectory
        case .core: base = locations.coreLogsDirectory
        }
        // Resolve symlinks on both sides: the enumerator may hand back `/private/var/...`
        // for a directory that was given as `/var/...`.
        let resolvedBase = base.resolvingSymlinksInPath().path
        let basePath = resolvedBase.hasSuffix("/") ? resolvedBase : resolvedBase + "/"
        let filePath = file.url.resolvingSymlinksInPath().path
        if filePath.hasPrefix(basePath) {
            return String(filePath.dropFirst(basePath.count))
        }
        return file.name
    }

    /// The on-disk files `options` asks for, sessions first, newest first within each kind.
    func selectedFiles(from sources: LogExportSourceSet, options: LogExportOptions) -> [LogExportFile] {
        var files: [LogExportFile] = []
        if options.includeSessionFiles { files += sources.sessionFiles }
        if options.includeCrashReports { files += sources.crashReports }
        if options.includeCoreLogs { files += sources.coreLogs }
        return files
    }

    /// Zips `directory` (as a top-level folder) to `destination` using Foundation's
    /// upload coordination, the same mechanism the log importer's test fixtures use.
    func zip(directory: URL, to destination: URL) throws {
#if canImport(Darwin)
        var coordinatorError: NSError?
        var copyError: Error?
        let fileManager = self.fileManager
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinatorError) { zippedURL in
            do {
                try fileManager.copyItem(at: zippedURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError { throw LogExportError.archiveFailed(error.localizedDescription) }
        if let error = copyError { throw LogExportError.archiveFailed(error.localizedDescription) }
#else
        throw LogExportError.zipUnsupported
#endif
    }

    // MARK: Housekeeping

    /// Deletes exports in `outputDirectory` older than `age`. Returns how many were removed.
    @discardableResult
    public func removeExports(olderThan age: TimeInterval) -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: outputDirectory,
                                                                  includingPropertiesForKeys: [.contentModificationDateKey],
                                                                  options: [.skipsHiddenFiles]) else { return 0 }
        let cutoff = Date().addingTimeInterval(-age)
        var removed = 0
        for url in contents {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            guard modified < cutoff, (try? fileManager.removeItem(at: url)) != nil else { continue }
            removed += 1
        }
        return removed
    }
}

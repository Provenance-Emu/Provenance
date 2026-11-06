//
//  LogExportSources.swift
//  PVLogging
//
//  Where on disk the exportable log files live, and what is actually there (#3612).
//

import Foundation

/// A file that can be added to an export.
public struct LogExportFile: Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// A `PVLogFileManager` session file.
        case session
        /// A crash, hang or CPU-exception payload.
        case crash
        /// A log written by an emulator core.
        case core
    }

    public var id: URL { url }
    public let url: URL
    public let kind: Kind
    public let size: Int64
    public let modificationDate: Date

    public init(url: URL, kind: Kind, size: Int64, modificationDate: Date) {
        self.url = url
        self.kind = kind
        self.size = size
        self.modificationDate = modificationDate
    }

    public var name: String { url.lastPathComponent }
}

/// Directories the exporter scans. Injected so tests can point at a temp tree.
public struct LogExportLocations: Equatable, Sendable {
    /// `PVLogFileManager` session logs (`*.log`).
    public var sessionLogsDirectory: URL
    /// MetricKit crash/hang payloads saved by the app (`Documents/Logs/MetricKit/*.json`).
    public var crashReportsDirectory: URL
    /// Legacy RetroArch core logs (`Documents/RetroArch/logs`), present only on upgraded installs.
    public var coreLogsDirectory: URL

    public init(sessionLogsDirectory: URL, crashReportsDirectory: URL, coreLogsDirectory: URL) {
        self.sessionLogsDirectory = sessionLogsDirectory
        self.crashReportsDirectory = crashReportsDirectory
        self.coreLogsDirectory = coreLogsDirectory
    }

    /// The app's real locations.
    public static var `default`: LogExportLocations {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return LogExportLocations(
            sessionLogsDirectory: PVLogFileManager.shared.logsDirectory,
            crashReportsDirectory: documents.appendingPathComponent("Logs/MetricKit", isDirectory: true),
            coreLogsDirectory: documents.appendingPathComponent("RetroArch/logs", isDirectory: true)
        )
    }

    /// File extensions accepted per kind. Core logs accept anything that is a regular file.
    static let sessionExtensions: Set<String> = ["log"]
    static let crashExtensions: Set<String> = ["json", "ips", "crash"]
}

/// Everything found on disk, newest first within each kind.
public struct LogExportSourceSet: Equatable, Sendable {
    public var sessionFiles: [LogExportFile]
    public var crashReports: [LogExportFile]
    public var coreLogs: [LogExportFile]

    public init(sessionFiles: [LogExportFile] = [], crashReports: [LogExportFile] = [], coreLogs: [LogExportFile] = []) {
        self.sessionFiles = sessionFiles
        self.crashReports = crashReports
        self.coreLogs = coreLogs
    }

    public var isEmpty: Bool { sessionFiles.isEmpty && crashReports.isEmpty && coreLogs.isEmpty }

    /// Files of `kind`.
    public func files(of kind: LogExportFile.Kind) -> [LogExportFile] {
        switch kind {
        case .session: return sessionFiles
        case .crash: return crashReports
        case .core: return coreLogs
        }
    }

    /// Scans `locations`. Missing directories simply contribute nothing.
    public static func scan(_ locations: LogExportLocations, fileManager: FileManager = .default) -> LogExportSourceSet {
        LogExportSourceSet(
            sessionFiles: files(in: locations.sessionLogsDirectory, kind: .session,
                                extensions: LogExportLocations.sessionExtensions, fileManager: fileManager),
            crashReports: files(in: locations.crashReportsDirectory, kind: .crash,
                                extensions: LogExportLocations.crashExtensions, fileManager: fileManager),
            coreLogs: files(in: locations.coreLogsDirectory, kind: .core, extensions: nil, fileManager: fileManager)
        )
    }

    private static let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]

    /// Regular files under `directory` (recursively), filtered by `extensions` when given.
    private static func files(in directory: URL,
                              kind: LogExportFile.Kind,
                              extensions: Set<String>?,
                              fileManager: FileManager) -> [LogExportFile] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let enumerator = fileManager.enumerator(at: directory,
                                                      includingPropertiesForKeys: Array(resourceKeys),
                                                      options: [.skipsHiddenFiles]) else {
            return []
        }

        var found: [LogExportFile] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: resourceKeys),
                  values.isRegularFile == true else { continue }
            if let extensions, !extensions.contains(url.pathExtension.lowercased()) { continue }
            found.append(LogExportFile(
                url: url,
                kind: kind,
                size: Int64(values.fileSize ?? 0),
                modificationDate: values.contentModificationDate ?? .distantPast
            ))
        }
        return found.sorted { lhs, rhs in
            if lhs.modificationDate != rhs.modificationDate { return lhs.modificationDate > rhs.modificationDate }
            return lhs.name < rhs.name
        }
    }
}

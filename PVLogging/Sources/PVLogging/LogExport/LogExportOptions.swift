//
//  LogExportOptions.swift
//  PVLogging
//
//  What a log export should contain and how it should be packaged (#3612).
//

import Foundation

/// User-selectable contents and packaging of a log export.
public struct LogExportOptions: Codable, Equatable, Sendable {
    /// Output container.
    public enum Format: String, Codable, CaseIterable, Sendable {
        /// One plain-text `.log` file: header, then every selected source concatenated.
        case text
        /// A `.zip` bundle with `manifest.json`, `device_info.txt` and the selected files.
        case zip

        /// File extension the export is written with.
        public var fileExtension: String {
            switch self {
            case .text: return "log"
            case .zip: return "zip"
            }
        }
    }

    public var format: Format
    /// The in-memory session shown in the viewer (`LogEntry` values passed to the exporter).
    public var includeAppLogs: Bool
    /// The app/device header (`device_info.txt` in a bundle, the top of a text export).
    public var includeDeviceInfo: Bool
    /// Date-stamped session files written by `PVLogFileManager` (current and rotated).
    public var includeSessionFiles: Bool
    /// Crash and hang payloads kept on disk (MetricKit JSON, `.ips`).
    public var includeCrashReports: Bool
    /// Log files written by emulator cores, when any exist on disk.
    public var includeCoreLogs: Bool
    /// Append `[File.swift:line]` to each in-memory entry.
    public var includeSourceLocation: Bool

    public init(
        format: Format = .zip,
        includeAppLogs: Bool = true,
        includeDeviceInfo: Bool = true,
        includeSessionFiles: Bool = true,
        includeCrashReports: Bool = true,
        includeCoreLogs: Bool = true,
        includeSourceLocation: Bool = false
    ) {
        self.format = format
        self.includeAppLogs = includeAppLogs
        self.includeDeviceInfo = includeDeviceInfo
        self.includeSessionFiles = includeSessionFiles
        self.includeCrashReports = includeCrashReports
        self.includeCoreLogs = includeCoreLogs
        self.includeSourceLocation = includeSourceLocation
    }

    /// True when nothing at all would be written.
    public var isEmpty: Bool {
        !(includeAppLogs || includeDeviceInfo || includeSessionFiles || includeCrashReports || includeCoreLogs)
    }

    /// Human-readable list of the selected sources, used in the header.
    public var includedSummary: String {
        var parts: [String] = []
        if includeDeviceInfo { parts.append("device info") }
        if includeAppLogs { parts.append("app logs") }
        if includeSessionFiles { parts.append("session files") }
        if includeCrashReports { parts.append("crash reports") }
        if includeCoreLogs { parts.append("core logs") }
        return parts.isEmpty ? "nothing" : parts.joined(separator: ", ")
    }
}

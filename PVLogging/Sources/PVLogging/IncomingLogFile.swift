//
//  IncomingLogFile.swift
//  PVLogging
//
//  Decides whether a file handed to the app (Files "Open in…", Mail, AirDrop,
//  a cold-launch document URL) is a Provenance log export that belongs in the
//  log viewer, or something the ROM importer should see instead (#3612).
//
//  Pure functions over the file's extension and, when that is ambiguous, over
//  the names inside a ZIP or the first bytes of a text file. The I/O that
//  produces those inputs lives in the UI layer (`LogFileRouter`); keeping the
//  decision here lets it be unit-tested with `swift test`.
//

import Foundation

public enum IncomingLogFile {

    /// What the file turned out to be.
    public enum Kind: Equatable, Sendable {
        /// A plain-text log: any `.log`, or a `.txt` that starts with an export header.
        case plainLog
        /// A ZIP produced by the log exporter, identified by its manifest or legacy entries.
        case logBundle
        /// Not a log; the existing import pipeline (ROMs, skins, …) handles it.
        case other
    }

    /// How much of the file must be looked at before `classify` can decide.
    public enum Inspection: Equatable, Sendable {
        /// The extension alone decides.
        case none
        /// The archive's entry paths are needed.
        case archiveEntries
        /// The first few hundred bytes of text are needed.
        case textPrefix
    }

    // MARK: - Export format markers

    /// First line of `device_info.txt` and of a `.log` text export.
    public static let exportHeader = "=== Provenance Log Export ==="

    /// Section header that precedes the app log lines in a text export.
    public static let appLogsHeader = "=== App Logs ==="

    /// Manifest that identifies an exported ZIP even when only on-disk logs are selected.
    public static let bundleManifestName = "provenance_log_manifest.json"

    /// Device/app info file inside an exported ZIP bundle.
    public static let bundleDeviceInfoName = "device_info.txt"

    /// App log file inside an exported ZIP bundle.
    public static let bundleAppLogsName = "app_logs.txt"

    /// Folder of RetroArch logs inside an exported ZIP bundle.
    public static let bundleRetroArchDirectory = "retroarch_logs"

    // MARK: - Extensions

    /// Extensions that are always a log, whatever the contents.
    public static let plainLogExtensions: Set<String> = ["log"]

    /// Archive extensions the exporter uses; decided by their entry names.
    public static let archiveExtensions: Set<String> = ["zip"]

    /// Text extensions decided by their first bytes.
    public static let textExtensions: Set<String> = ["txt"]

    /// Enough bytes to cover a BOM, leading blank lines and the export header.
    public static let textPrefixByteCount = 256

    // MARK: - Classification

    /// Which inputs `classify` needs for a file with this extension.
    public static func inspection(for fileExtension: String) -> Inspection {
        let ext = fileExtension.lowercased()
        if plainLogExtensions.contains(ext) { return .none }
        if archiveExtensions.contains(ext) { return .archiveEntries }
        if textExtensions.contains(ext) { return .textPrefix }
        return .none
    }

    /// Classifies a file from its extension plus whatever `inspection(for:)` asked for.
    ///
    /// - Parameters:
    ///   - fileExtension: The path extension, any case.
    ///   - archiveEntryPaths: Paths of every entry in the ZIP, when the file is an
    ///     archive. `nil` (unreadable, or not asked for) classifies as `.other`.
    ///   - textPrefix: The first bytes of the file decoded as text, when it is a
    ///     `.txt`. `nil` classifies as `.other`.
    public static func classify(fileExtension: String,
                                archiveEntryPaths: [String]? = nil,
                                textPrefix: String? = nil) -> Kind {
        switch inspection(for: fileExtension) {
        case .none:
            return plainLogExtensions.contains(fileExtension.lowercased()) ? .plainLog : .other
        case .archiveEntries:
            guard let paths = archiveEntryPaths, isLogBundle(entryPaths: paths) else { return .other }
            return .logBundle
        case .textPrefix:
            guard let prefix = textPrefix, isExportedLogText(prefix) else { return .other }
            return .plainLog
        }
    }

    /// Whether a ZIP's entry list matches an exported log bundle.
    ///
    /// The exporter zips a staging folder, so entries are usually nested one
    /// level (`pv_log_export_<ts>/device_info.txt`); only the last path component
    /// is compared. Directory entries (trailing `/`) and `__MACOSX` resource-fork
    /// copies (`._name`) do not match.
    public static func isLogBundle(entryPaths: [String]) -> Bool {
        let markerFiles = [bundleManifestName, bundleDeviceInfoName, bundleAppLogsName]
        return entryPaths.contains { path in
            let components = path.split(separator: "/").map { $0.lowercased() }
            guard let last = components.last else { return false }
            if components.contains(bundleRetroArchDirectory) { return true }
            return markerFiles.contains(last) && !path.hasSuffix("/")
        }
    }

    /// Whether text starts with one of the exporter's section headers.
    ///
    /// A UTF-8 BOM and leading whitespace are ignored; anything else in front of
    /// the header (a RetroArch config, a cheat list, a README) is not a log export.
    public static func isExportedLogText(_ prefix: String) -> Bool {
        var trimmed = Substring(prefix)
        if trimmed.hasPrefix("\u{FEFF}") { trimmed = trimmed.dropFirst() }
        while let first = trimmed.first, first.isWhitespace || first.isNewline {
            trimmed = trimmed.dropFirst()
        }
        return trimmed.hasPrefix(exportHeader) || trimmed.hasPrefix(appLogsHeader)
    }
}

//
//  LogExportHeader.swift
//  PVLogging
//
//  App, device and OS metadata written at the top of every log export (#3612).
//

import Foundation

/// Metadata block that opens a text export and is `device_info.txt` in a bundle.
///
/// Every field is plain data so tests can render a known header; `current(options:)`
/// fills it from `Bundle.main` and the running system.
public struct LogExportHeader: Codable, Equatable, Sendable {
    public var appName: String
    public var appVersion: String
    public var appBuild: String
    public var bundleIdentifier: String
    public var deviceModel: String
    public var osName: String
    public var osVersion: String
    /// Extra platform note, e.g. "macOS (iOS app on Mac)". `nil` when there is nothing to add.
    public var hostNote: String?
    public var exportDate: Date
    /// Count of in-memory entries being exported (after the viewer's filter).
    public var entryCount: Int
    /// Count of entries in the whole in-memory session.
    public var totalEntryCount: Int
    public var options: LogExportOptions

    public init(
        appName: String,
        appVersion: String,
        appBuild: String,
        bundleIdentifier: String,
        deviceModel: String,
        osName: String,
        osVersion: String,
        hostNote: String? = nil,
        exportDate: Date = Date(),
        entryCount: Int = 0,
        totalEntryCount: Int = 0,
        options: LogExportOptions = LogExportOptions()
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.bundleIdentifier = bundleIdentifier
        self.deviceModel = deviceModel
        self.osName = osName
        self.osVersion = osVersion
        self.hostNote = hostNote
        self.exportDate = exportDate
        self.entryCount = entryCount
        self.totalEntryCount = totalEntryCount
        self.options = options
    }

    // MARK: - Rendering

    /// First line of every export; the importer and humans both key off it.
    public static let title = "=== Provenance Log Export ==="

    /// Renders the header as `Key: value` lines under `title`.
    public func render() -> String {
        var lines: [String] = [Self.title]
        lines.append("Date: \(Self.dateFormatter.string(from: exportDate))")
        lines.append("App: \(appName) \(appVersion) (\(appBuild))")
        lines.append("Bundle: \(bundleIdentifier)")
        lines.append("Device: \(deviceModel)")
        lines.append("OS: \(osName) \(osVersion)")
        if let hostNote, !hostNote.isEmpty {
            lines.append("Host: \(hostNote)")
        }
        lines.append("Format: \(options.format.rawValue)")
        lines.append("Included: \(options.includedSummary)")
        lines.append("Log Entries: \(entryCount) (total in session: \(totalEntryCount))")
        return lines.joined(separator: "\n") + "\n"
    }

    /// ISO 8601 with the local offset, so a report's wall-clock time survives the trip.
    /// Built per call: `ISO8601DateFormatter` is not `Sendable`, and headers are rendered rarely.
    private static var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        return formatter
    }

    // MARK: - Current environment

    /// Builds the header for the running app.
    public static func current(
        options: LogExportOptions,
        entryCount: Int,
        totalEntryCount: Int,
        bundle: Bundle = .main,
        date: Date = Date()
    ) -> LogExportHeader {
        let info = bundle.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? "Provenance"
        return LogExportHeader(
            appName: name,
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info["CFBundleVersion"] as? String ?? "unknown",
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            deviceModel: currentDeviceModel(),
            osName: currentOSName,
            osVersion: currentOSVersion,
            hostNote: currentHostNote,
            exportDate: date,
            entryCount: entryCount,
            totalEntryCount: totalEntryCount,
            options: options
        )
    }

    /// Hardware identifier such as `iPhone15,2`; the simulated model when running in a simulator.
    static func currentDeviceModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return "\(simulated) (Simulator)"
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: pointer.pointee)) {
                String(cString: $0)
            }
        }
        return machine.isEmpty ? "unknown" : machine
    }

    static var currentOSName: String {
#if os(iOS)
        return "iOS"
#elseif os(tvOS)
        return "tvOS"
#elseif os(watchOS)
        return "watchOS"
#elseif os(visionOS)
        return "visionOS"
#elseif os(macOS)
        return "macOS"
#elseif os(Linux)
        return "Linux"
#else
        return "unknown"
#endif
    }

    static var currentOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    /// "Designed for iPad" on a Mac reports an iPad model and iPadOS, which hides the
    /// real host from every log a Mac user sends; call it out explicitly.
    static var currentHostNote: String? {
#if os(iOS)
        return ProcessInfo.processInfo.isiOSAppOnMac ? "macOS (iOS app on Mac)" : nil
#else
        return nil
#endif
    }
}

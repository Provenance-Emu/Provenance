//
//  ExtensionRunMarker.swift
//  PVSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Records that an app-extension invocation *started* and, on clean completion,
//  that it *finished*. A marker left behind means the previous invocation of
//  that extension died without finishing.
//
//  Why not just add a crash SDK to the extensions?
//  ----------------------------------------------
//  The suspected terminations here are jetsam (memory-limit / memory-pressure
//  kills) and `0xdead10cc` (suspended while holding a file or sqlite lock).
//  Both are delivered as SIGKILL, which is uncatchable — no in-process crash
//  handler, Sentry's included, can ever run for them. A crash SDK inside a
//  memory-capped Spotlight extension would add weight to the very process we
//  are trying to keep under its ceiling, while still missing the failure mode.
//
//  A marker file catches *every* unclean exit — jetsam, SIGKILL, watchdog and
//  ordinary signal crashes alike — for a few hundred bytes of I/O. The captured
//  memory footprint is what discriminates between them afterwards: an unclean
//  exit at a high footprint with no headroom reads as jetsam; one at a low
//  footprint with headroom to spare reads as a signal crash (and *that* is the
//  case where adding a crash SDK to the extension would pay for itself).
//
//  Storage is a file, not `UserDefaults`: App Group defaults writes are
//  asynchronous and coalesced, so a process SIGKILLed moments after setting a
//  key can lose the write — precisely the case being recorded. Marker writes
//  are single atomic file replacements, which survive.
//

import Foundation

#if canImport(Darwin)
import Darwin
#endif

#if !os(macOS)
import os
#endif

/// A recovered record of one app-extension invocation that never finished.
public struct ExtensionRunRecord: Codable, Equatable, Sendable {
    /// Short extension name, e.g. `"Spotlight"`. Used as the Sentry tag value.
    public let extensionName: String
    /// Last checkpoint the extension reached before it died.
    public let phase: String
    /// When the invocation started.
    public let startedAt: Date
    /// When the last checkpoint was written.
    public let updatedAt: Date
    /// `phys_footprint` in bytes at the last checkpoint. Always available.
    public let footprintBytes: UInt64
    /// Bytes the process could still allocate at the last checkpoint.
    /// `0` means "unknown" — `os_proc_available_memory()` documents a `0`
    /// return for non-app processes as well as for over-limit processes, so it
    /// cannot be distinguished and must not be read as "no headroom".
    public let availableMemoryBytes: UInt64
    /// Host app build that wrote the marker, for correlating across releases.
    public let appBuildVersion: String

    public init(
        extensionName: String,
        phase: String,
        startedAt: Date,
        updatedAt: Date,
        footprintBytes: UInt64,
        availableMemoryBytes: UInt64,
        appBuildVersion: String
    ) {
        self.extensionName = extensionName
        self.phase = phase
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.footprintBytes = footprintBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.appBuildVersion = appBuildVersion
    }

    /// How long the invocation ran before dying.
    public var duration: TimeInterval { updatedAt.timeIntervalSince(startedAt) }

    /// Best-effort classification of *why* the invocation died.
    ///
    /// This is a heuristic for triage, not a verdict — cross-check the totals
    /// against MetricKit's `MXAppExitMetric` in the host app.
    public var likelyCause: String {
        /// A known-good reading near zero means the process was out of headroom.
        if availableMemoryBytes > 0, availableMemoryBytes < Self.lowMemoryHeadroomBytes {
            return "jetsam"
        }
        if footprintBytes >= Self.highFootprintBytes {
            return "jetsam"
        }
        return "unknown"
    }

    /// Below this much remaining allocatable memory, a kill is almost certainly jetsam.
    static let lowMemoryHeadroomBytes: UInt64 = 4 * 1024 * 1024
    /// App extensions are capped in the tens of MB; at or above this a jetsam is likely.
    static let highFootprintBytes: UInt64 = 40 * 1024 * 1024

    /// Low-cardinality tags for a crash-reporting backend.
    public var reportingTags: [String: String] {
        [
            "extension.name": extensionName,
            "extension.phase": phase,
            "extension.likely_cause": likelyCause
        ]
    }

    public var summaryLine: String {
        let footprintMB = Double(footprintBytes) / (1024 * 1024)
        let availableMB = Double(availableMemoryBytes) / (1024 * 1024)
        let available = availableMemoryBytes == 0 ? "unknown" : String(format: "%.1fMB", availableMB)
        return String(
            format: "%@ died in phase=%@ after %.1fs footprint=%.1fMB available=%@ cause=%@",
            extensionName, phase, duration, footprintMB, available, likelyCause
        )
    }
}

/// Writes and clears the run marker for a single app extension.
///
/// Usage inside an extension:
/// ```swift
/// private let marker = ExtensionRunMarker(extensionName: "Spotlight")
/// // FIRST statement of the entry point, before any Realm/database access:
/// marker.begin(phase: "init")
/// ...
/// marker.checkpoint("indexing")
/// ...
/// marker.finish()   // in the completion/acknowledgement callback, not deinit
/// ```
///
/// Extensions are killed rather than deallocated, so `finish()` must be called
/// from the completion handler that signals the work is done — never `deinit`.
///
/// There is one marker file per extension, so two overlapping invocations in the
/// same process share it and the first `finish()` clears the marker for both.
/// That biases towards **under**-reporting, never towards false positives, which
/// is the safe direction for a diagnostic: a reported termination is always real.
public final class ExtensionRunMarker {
    /// Subdirectory of the App Group container holding one file per extension.
    static let directoryName = "Diagnostics/ExtensionRuns"

    private let extensionName: String
    private let startedAt: Date
    private let fileURL: URL?

    public init(extensionName: String, date: Date = Date()) {
        self.extensionName = extensionName
        self.startedAt = date
        self.fileURL = Self.markerURL(for: extensionName)
    }

    // MARK: - Writing (extension side)

    /// Record that this invocation started. Call as the first statement of the
    /// extension entry point — before opening Realm — so a failure during
    /// database initialisation is still captured.
    public func begin(phase: String = "begin") {
        write(phase: phase)
    }

    /// Update the recorded phase and memory reading.
    public func checkpoint(_ phase: String) {
        write(phase: phase)
    }

    /// Record a clean completion by removing the marker.
    public func finish() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func write(phase: String) {
        guard let fileURL else { return }
        let record = ExtensionRunRecord(
            extensionName: extensionName,
            phase: phase,
            startedAt: startedAt,
            updatedAt: Date(),
            footprintBytes: Self.physicalFootprintBytes(),
            availableMemoryBytes: Self.availableMemoryBytes(),
            appBuildVersion: Self.buildVersion
        )
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        /// Atomic so a SIGKILL mid-write cannot leave a truncated marker.
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Reading (host app side)

    /// Return every marker left behind by an extension that never finished, and
    /// remove them so each unclean exit is reported exactly once.
    ///
    /// Call from the host app at launch. Markers for invocations still in flight
    /// are indistinguishable from dead ones, so `minimumAge` skips very recent
    /// markers rather than reporting a live extension as a casualty.
    public static func consumePendingRecords(
        minimumAge: TimeInterval = defaultMinimumAge,
        now: Date = Date()
    ) -> [ExtensionRunRecord] {
        guard let directory = markerDirectory() else { return [] }
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        var records: [ExtensionRunRecord] = []
        for url in urls where url.pathExtension == markerFileExtension {
            guard let data = try? Data(contentsOf: url),
                  let record = try? JSONDecoder().decode(ExtensionRunRecord.self, from: data) else {
                /// Unreadable marker — drop it so it cannot accumulate forever.
                try? fileManager.removeItem(at: url)
                continue
            }
            guard now.timeIntervalSince(record.updatedAt) >= minimumAge else { continue }
            records.append(record)
            try? fileManager.removeItem(at: url)
        }
        return records.sorted { $0.updatedAt < $1.updatedAt }
    }

    /// An extension younger than this may still be running; don't report it yet.
    public static let defaultMinimumAge: TimeInterval = 60

    // MARK: - Paths

    /// The App Group identifier for this build.
    ///
    /// PVSupport deliberately does not depend on PVLibrary (that would be a tier
    /// inversion), so the resolution is duplicated here. The canonical
    /// definition is `PVLibrary/Sources/PVFileSystem/Paths.swift` →
    /// `public let PVAppGroupId`; both read the same Info.plist key, so the two
    /// always agree for a given build. Same pattern as
    /// `PVAppIntents/Sources/PVAppIntents/AppGroupID.swift`.
    static var appGroupIdentifier: String {
        let raw = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
        /// Guard against unexpanded Xcode build-variable placeholders.
        guard let raw, !raw.isEmpty, !raw.contains("$(") else {
            return "group.org.provenance-emu.provenance"
        }
        return raw
    }

    static let markerFileExtension = "json"

    static func markerDirectory() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static func markerURL(for extensionName: String) -> URL? {
        /// Keep the filename filesystem-safe regardless of the caller's string.
        let safeName = extensionName.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        return markerDirectory()?.appendingPathComponent("\(safeName).\(markerFileExtension)")
    }

    // MARK: - Memory readings

    private static var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    /// Bytes this process can still allocate, or `0` when unavailable.
    static func availableMemoryBytes() -> UInt64 {
#if os(macOS)
        return 0
#else
        return UInt64(os_proc_available_memory())
#endif
    }

    /// `phys_footprint` — the number jetsam actually compares against the limit.
    static func physicalFootprintBytes() -> UInt64 {
#if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.phys_footprint)
#else
        return 0
#endif
    }
}

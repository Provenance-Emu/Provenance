//
//  PVLaunchProfiler.swift
//  PVLogging
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Launch-path profiling. Emits BOTH an `os_signpost` interval (readable in
//  Instruments' "Points of Interest" / custom `launch` category) AND a plain
//  `ILOG` line carrying the measured duration in milliseconds.
//
//  The dual emit is deliberate: Instruments gives the timeline view, but the
//  established debugging idiom for this app is Console.app filtered on
//  `Process = Provenance` (Xcode-attached debugging is broken for several core
//  paths — see CLAUDE.md). A signpost-only solution would be unreadable
//  without an Instruments trace, which is not always practical on device.
//
//  HOW TO READ ON DEVICE
//  ---------------------
//  Console.app → filter `Process = Provenance`, then search `LAUNCH:`.
//  Every completed phase logs one line:
//
//      LAUNCH: <phase> took <n>ms (t+<m>ms)
//
//  where `<n>` is the phase's own wall duration and `<m>` is the elapsed time
//  since ``PVLaunchProfiler/markProcessStart()`` (called at the top of
//  `application(_:didFinishLaunchingWithOptions:)`). Sorting the `t+` values
//  reconstructs the whole boot timeline without Instruments.
//
//  In Instruments: File → Recording Options → add "os_signpost", filter on
//  subsystem `Logger.provenanceSubsystem`, category `launch`.
//

import Foundation

#if canImport(OSLog)
import OSLog
#endif

/// Profiles discrete phases of application launch.
///
/// All measurement is monotonic (`DispatchTime`), so it is unaffected by wall
/// clock adjustments. Overhead is a timestamp read and one log line per phase,
/// which is negligible next to the phases being measured.
public enum PVLaunchProfiler {

    // MARK: - Constants

    /// Nanoseconds in one millisecond, used to convert `DispatchTime` deltas.
    private static let nanosecondsPerMillisecond: Double = 1_000_000

    /// Prefix on every emitted log line. Search for this in Console.app.
    private static let logPrefix = "LAUNCH:"

#if canImport(OSLog)
    /// Signpost log for launch-phase intervals. Shows up in Instruments under
    /// the `launch` category of the Provenance subsystem.
    public static let signpostLog = OSLog(
        subsystem: os.Logger.provenanceSubsystem,
        category: "launch"
    )
#endif

    // MARK: - Process origin

    /// Monotonic origin used for the `t+` column in log output.
    ///
    /// `nonisolated(unsafe)` is sound here: it is written once from
    /// `markProcessStart()` on the main thread at the very top of
    /// `didFinishLaunchingWithOptions` — strictly before any launch phase can
    /// run — and only read afterwards.
    nonisolated(unsafe) private static var processStart: DispatchTime?

    /// Records the launch origin. Call once, as early as possible in
    /// `application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// Calling it more than once is a no-op so a re-entrant launch path cannot
    /// reset the timeline mid-measurement.
    public static func markProcessStart() {
        guard processStart == nil else { return }
        processStart = DispatchTime.now()
    }

    /// Milliseconds elapsed since ``markProcessStart()``, or `nil` if the
    /// origin was never recorded.
    private static func elapsedSinceStartMilliseconds() -> Double? {
        guard let processStart else { return nil }
        return milliseconds(from: processStart, to: DispatchTime.now())
    }

    /// Monotonic millisecond delta between two `DispatchTime` values.
    private static func milliseconds(from start: DispatchTime, to end: DispatchTime) -> Double {
        Double(end.uptimeNanoseconds &- start.uptimeNanoseconds) / nanosecondsPerMillisecond
    }

    // MARK: - Reporting

    /// Emits the log line for a finished phase.
    ///
    /// - Parameters:
    ///   - label: Human-readable phase name.
    ///   - durationMilliseconds: Wall duration of the phase.
    private static func report(_ label: String, durationMilliseconds: Double) {
        let duration = String(format: "%.1f", durationMilliseconds)
        if let sinceStart = elapsedSinceStartMilliseconds() {
            let total = String(format: "%.1f", sinceStart)
            ILOG("\(logPrefix) \(label) took \(duration)ms (t+\(total)ms)")
        } else {
            ILOG("\(logPrefix) \(label) took \(duration)ms")
        }
    }

    // MARK: - Measurement

    /// Measures an async phase, emitting a signpost interval and a log line.
    ///
    /// The result and any thrown error propagate unchanged, so this can be
    /// wrapped around existing calls without altering control flow.
    ///
    /// - Parameters:
    ///   - label: Human-readable phase name, used in the log line.
    ///   - body: The work to measure.
    /// - Returns: Whatever `body` returns.
    @discardableResult
    public static func measure<T>(
        _ label: String,
        _ body: () async throws -> T
    ) async rethrows -> T {
        let start = DispatchTime.now()
#if canImport(OSLog)
        let id = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "LaunchPhase", signpostID: id, "%{public}@", label)
#endif
        defer {
#if canImport(OSLog)
            os_signpost(.end, log: signpostLog, name: "LaunchPhase", signpostID: id, "%{public}@", label)
#endif
            report(label, durationMilliseconds: milliseconds(from: start, to: DispatchTime.now()))
        }
        return try await body()
    }

    /// Measures a synchronous phase, emitting a signpost interval and a log line.
    ///
    /// - Parameters:
    ///   - label: Human-readable phase name, used in the log line.
    ///   - body: The work to measure.
    /// - Returns: Whatever `body` returns.
    @discardableResult
    public static func measure<T>(
        _ label: String,
        _ body: () throws -> T
    ) rethrows -> T {
        let start = DispatchTime.now()
#if canImport(OSLog)
        let id = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "LaunchPhase", signpostID: id, "%{public}@", label)
#endif
        defer {
#if canImport(OSLog)
            os_signpost(.end, log: signpostLog, name: "LaunchPhase", signpostID: id, "%{public}@", label)
#endif
            report(label, durationMilliseconds: milliseconds(from: start, to: DispatchTime.now()))
        }
        return try body()
    }

    /// Emits an instantaneous milestone (no interval), e.g. "first frame".
    ///
    /// - Parameter label: Human-readable milestone name.
    public static func milestone(_ label: String) {
#if canImport(OSLog)
        os_signpost(.event, log: signpostLog, name: "LaunchMilestone", "%{public}@", label)
#endif
        if let sinceStart = elapsedSinceStartMilliseconds() {
            let total = String(format: "%.1f", sinceStart)
            ILOG("\(logPrefix) \(label) (t+\(total)ms)")
        } else {
            ILOG("\(logPrefix) \(label)")
        }
    }
}

//
//  AppExitSummary.swift
//  PVUI
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Pure, SDK-free model of MetricKit's `MXAppExitMetric`. Kept free of any
//  `import MetricKit` so the mapping logic is unit-testable on every platform
//  (MetricKit is `API_UNAVAILABLE(tvos, watchos)`).
//
//  Why this exists: `MXAppExitMetric` is the ONLY first-party API that reports
//  jetsam (memory-limit / memory-pressure kills) and `0xdead10cc` (suspended
//  while holding a file or sqlite lock). Those are SIGKILL terminations — no
//  crash handler, Sentry's included, can ever observe them in-process. Before
//  this type existed the app read only launch/time metrics, so every background
//  jetsam was invisible in both the local logs and Sentry.
//

import Foundation

/// Cumulative exit counters for a single scope (foreground or background).
///
/// Field names mirror `MXForegroundExitData` / `MXBackgroundExitData`. Counters
/// that only exist on the background variant are reported as `0` for foreground.
public struct AppExitCounts: Equatable, Sendable {
    /// Clean exits — user swiped the app away, or the system reclaimed it normally.
    public let normal: Int
    /// Jetsam: exceeded the per-process memory limit. SIGKILL, uncatchable.
    public let memoryResourceLimit: Int
    /// Jetsam: killed because the whole device was under memory pressure. Background only.
    public let memoryPressure: Int
    /// Exceeded the background CPU budget. Background only.
    public let cpuResourceLimit: Int
    /// EXC_BAD_ACCESS — the classic segfault.
    public let badAccess: Int
    /// Uncaught ObjC/C++ exception or `abort()`.
    public let abnormal: Int
    /// Jumped to an invalid address / undefined instruction.
    public let illegalInstruction: Int
    /// Watchdog: took too long to launch, suspend, or respond to a system event.
    public let watchdog: Int
    /// `0xdead10cc` — suspended while holding a file or sqlite lock. Background only.
    public let suspendedWithLockedFile: Int
    /// Began a `UIBackgroundTask` and never called `endBackgroundTask`. Background only.
    public let backgroundTaskAssertionTimeout: Int

    public init(
        normal: Int,
        memoryResourceLimit: Int,
        memoryPressure: Int = 0,
        cpuResourceLimit: Int = 0,
        badAccess: Int,
        abnormal: Int,
        illegalInstruction: Int,
        watchdog: Int,
        suspendedWithLockedFile: Int = 0,
        backgroundTaskAssertionTimeout: Int = 0
    ) {
        self.normal = normal
        self.memoryResourceLimit = memoryResourceLimit
        self.memoryPressure = memoryPressure
        self.cpuResourceLimit = cpuResourceLimit
        self.badAccess = badAccess
        self.abnormal = abnormal
        self.illegalInstruction = illegalInstruction
        self.watchdog = watchdog
        self.suspendedWithLockedFile = suspendedWithLockedFile
        self.backgroundTaskAssertionTimeout = backgroundTaskAssertionTimeout
    }

    /// Every exit that was *not* a clean shutdown.
    public var abnormalTotal: Int {
        memoryResourceLimit + memoryPressure + cpuResourceLimit + badAccess
            + abnormal + illegalInstruction + watchdog
            + suspendedWithLockedFile + backgroundTaskAssertionTimeout
    }

    /// Memory-driven SIGKILLs. This is the counter the "app dies in the
    /// background / next boot is slow" reports are expected to move.
    public var jetsamTotal: Int { memoryResourceLimit + memoryPressure }

    /// `true` when there is anything worth reporting upstream.
    public var hasAbnormalExits: Bool { abnormalTotal > 0 }

    /// Non-zero counters rendered as `key=value` pairs, stable ordering.
    /// Zero counters are omitted so a report is readable at a glance.
    public var nonZeroCounters: [(name: String, count: Int)] {
        let all: [(String, Int)] = [
            ("memoryResourceLimit", memoryResourceLimit),
            ("memoryPressure", memoryPressure),
            ("cpuResourceLimit", cpuResourceLimit),
            ("badAccess", badAccess),
            ("abnormal", abnormal),
            ("illegalInstruction", illegalInstruction),
            ("watchdog", watchdog),
            ("suspendedWithLockedFile", suspendedWithLockedFile),
            ("backgroundTaskAssertionTimeout", backgroundTaskAssertionTimeout)
        ]
        return all.filter { $0.1 > 0 }.map { (name: $0.0, count: $0.1) }
    }

    /// One-line human-readable summary, e.g. `normal=12 memoryResourceLimit=3`.
    public var summaryLine: String {
        let parts = ["normal=\(normal)"] + nonZeroCounters.map { "\($0.name)=\($0.count)" }
        return parts.joined(separator: " ")
    }
}

/// Foreground + background exit counters from one `MXMetricPayload`.
public struct AppExitSummary: Equatable, Sendable {
    public let foreground: AppExitCounts
    public let background: AppExitCounts

    public init(foreground: AppExitCounts, background: AppExitCounts) {
        self.foreground = foreground
        self.background = background
    }

    public var hasAbnormalExits: Bool {
        foreground.hasAbnormalExits || background.hasAbnormalExits
    }

    /// Sentry tags. Kept to low-cardinality booleans/counts so the specific
    /// termination classes the user reported are filterable in the dashboard.
    public var sentryTags: [String: String] {
        var tags: [String: String] = [
            "exit.background.jetsam": String(background.jetsamTotal),
            "exit.background.locked_file": String(background.suspendedWithLockedFile),
            "exit.background.watchdog": String(background.watchdog),
            "exit.background.abnormal_total": String(background.abnormalTotal),
            "exit.foreground.jetsam": String(foreground.jetsamTotal),
            "exit.foreground.abnormal_total": String(foreground.abnormalTotal)
        ]
        /// Coarse classifier so alerts can key off a single tag.
        tags["exit.dominant_class"] = dominantClass
        return tags
    }

    /// The single largest abnormal-exit bucket across both scopes, or `none`.
    public var dominantClass: String {
        let combined = (foreground.nonZeroCounters + background.nonZeroCounters)
            .reduce(into: [String: Int]()) { $0[$1.name, default: 0] += $1.count }
        guard let best = combined.max(by: { lhs, rhs in
            /// Break ties by name so the value is deterministic.
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }) else {
            return "none"
        }
        return best.key
    }

    public var summaryLine: String {
        "foreground[\(foreground.summaryLine)] background[\(background.summaryLine)]"
    }
}

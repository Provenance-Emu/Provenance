//
//  AppExitSummary+MetricKit.swift
//  PVUI
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Bridges `MXAppExitMetric` into the SDK-free `AppExitSummary`. Split from the
//  model so the mapping stays testable without MetricKit (unavailable on tvOS).
//

import Foundation

#if canImport(MetricKit) && !os(tvOS)
import MetricKit

@available(iOS 14.0, macOS 11.0, *)
public extension AppExitCounts {
    /// Foreground exits. `MXForegroundExitData` has no memory-pressure,
    /// CPU-limit, locked-file or background-task-timeout counters, so those
    /// stay at their `0` defaults.
    init(_ data: MXForegroundExitData) {
        self.init(
            normal: Int(data.cumulativeNormalAppExitCount),
            memoryResourceLimit: Int(data.cumulativeMemoryResourceLimitExitCount),
            badAccess: Int(data.cumulativeBadAccessExitCount),
            abnormal: Int(data.cumulativeAbnormalExitCount),
            illegalInstruction: Int(data.cumulativeIllegalInstructionExitCount),
            watchdog: Int(data.cumulativeAppWatchdogExitCount)
        )
    }

    /// Background exits — the scope that carries jetsam (`memoryResourceLimit`,
    /// `memoryPressure`) and `0xdead10cc` (`suspendedWithLockedFile`).
    init(_ data: MXBackgroundExitData) {
        self.init(
            normal: Int(data.cumulativeNormalAppExitCount),
            memoryResourceLimit: Int(data.cumulativeMemoryResourceLimitExitCount),
            memoryPressure: Int(data.cumulativeMemoryPressureExitCount),
            cpuResourceLimit: Int(data.cumulativeCPUResourceLimitExitCount),
            badAccess: Int(data.cumulativeBadAccessExitCount),
            abnormal: Int(data.cumulativeAbnormalExitCount),
            illegalInstruction: Int(data.cumulativeIllegalInstructionExitCount),
            watchdog: Int(data.cumulativeAppWatchdogExitCount),
            suspendedWithLockedFile: Int(data.cumulativeSuspendedWithLockedFileExitCount),
            backgroundTaskAssertionTimeout: Int(data.cumulativeBackgroundTaskAssertionTimeoutExitCount)
        )
    }
}

@available(iOS 14.0, macOS 11.0, *)
public extension AppExitSummary {
    init(_ metric: MXAppExitMetric) {
        self.init(
            foreground: AppExitCounts(metric.foregroundExitData),
            background: AppExitCounts(metric.backgroundExitData)
        )
    }
}
#endif

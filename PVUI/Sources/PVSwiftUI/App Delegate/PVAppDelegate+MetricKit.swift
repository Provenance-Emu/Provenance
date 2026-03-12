//
//  PVAppDelegate+MetricKit.swift
//  Provenance
//
//  Created by Claude on 2026-03-12.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Passive MetricKit subscriber that captures hang diagnostics shipped in iOS 14+.
//  Zero overhead in normal operation — the OS batches and delivers reports once per day
//  (or on first launch after a hang) via `didReceive(_:from:)`.
//

import Foundation
import PVLogging

#if canImport(MetricKit)
import MetricKit

@available(iOS 14.0, tvOS 14.0, *)
extension PVAppDelegate: MXMetricManagerSubscriber {

    /// Register this delegate as a MetricKit subscriber at app launch.
    /// Call from `application(_:didFinishLaunchingWithOptions:)`.
    func registerMetricKitSubscriber() {
        MXMetricManager.shared.add(self)
        ILOG("MetricKit: subscriber registered")
    }

    /// Unregister the subscriber (e.g. on applicationWillTerminate).
    func unregisterMetricKitSubscriber() {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber

    /// Called once per day (approximately) with aggregated performance metrics.
    public func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            ILOG("MetricKit metrics: applicationTimeMetrics=\(String(describing: payload.applicationTimeMetrics)), histogrammedTimeToFirstDraw=\(String(describing: payload.applicationLaunchMetrics))")
        }
    }

    /// Called shortly after a hang or crash occurs with diagnostic call stacks.
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logHangDiagnostics(payload)
            logCrashDiagnostics(payload)
            logCPUExceptionDiagnostics(payload)
        }
    }

    // MARK: - Private helpers

    private func logHangDiagnostics(_ payload: MXDiagnosticPayload) {
        guard let hangs = payload.hangDiagnostics, !hangs.isEmpty else { return }
        for hang in hangs {
            let duration = hang.hangDuration
            ELOG("MetricKit HANG detected — duration: \(duration)")
            // Log each call tree frame to the console so it appears in crash logs / Console.app
            if let tree = hang.callStackTree {
                let json = (try? JSONEncoder().encode(tree)).flatMap { String(data: $0, encoding: .utf8) }
                ELOG("MetricKit hang call stack:\n\(json ?? "<unavailable>")")
            }
        }
    }

    private func logCrashDiagnostics(_ payload: MXDiagnosticPayload) {
        guard let crashes = payload.crashDiagnostics, !crashes.isEmpty else { return }
        for crash in crashes {
            ELOG("MetricKit CRASH — signal: \(crash.signal), exception type: \(String(describing: crash.exceptionType)), exception code: \(String(describing: crash.exceptionCode))")
            if let tree = crash.callStackTree {
                let json = (try? JSONEncoder().encode(tree)).flatMap { String(data: $0, encoding: .utf8) }
                ELOG("MetricKit crash call stack:\n\(json ?? "<unavailable>")")
            }
        }
    }

    private func logCPUExceptionDiagnostics(_ payload: MXDiagnosticPayload) {
        guard let exceptions = payload.cpuExceptionDiagnostics, !exceptions.isEmpty else { return }
        for exception in exceptions {
            ELOG("MetricKit CPU EXCEPTION — total CPU time: \(exception.totalCPUTime), total sampled time: \(exception.totalSampledTime)")
            if let tree = exception.callStackTree {
                let json = (try? JSONEncoder().encode(tree)).flatMap { String(data: $0, encoding: .utf8) }
                ELOG("MetricKit CPU exception call stack:\n\(json ?? "<unavailable>")")
            }
        }
    }
}
#endif

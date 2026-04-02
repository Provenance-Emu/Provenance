//
//  PVAppDelegate+MetricKit.swift
//  Provenance
//
//  Created by Claude on 2026-03-12.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Passive MetricKit subscriber that captures hang, crash, and CPU-exception
//  diagnostics. Reports are written to a dedicated PVLogChannel with file output
//  and also saved as individual JSON files for offline symbolication.
//

import Foundation
import PVLogging

#if canImport(MetricKit) && !os(tvOS)
import MetricKit

extension PVAppDelegate: MXMetricManagerSubscriber {

    /// Dedicated log channel for MetricKit diagnostics.
    /// File output goes to `Documents/Logs/metrickit.log` (Caches on tvOS).
    static let metricLog: PVLogChannel = {
        let channel = PVLogChannel("metrickit", fileOutput: true, maxEntries: 200)
        PVLogChannelRegistry.shared.register(channel)
        return channel
    }()

    /// Register this delegate as a MetricKit subscriber at app launch.
    func registerMetricKitSubscriber() {
        MXMetricManager.shared.add(self)
        Self.metricLog.info("Subscriber registered")
    }

    /// Unregister the subscriber (e.g. on applicationWillTerminate).
    func unregisterMetricKitSubscriber() {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber

    public func didReceive(_ payloads: [MXMetricPayload]) {
        let log = Self.metricLog
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                log.info("Launch metrics: timeToFirstDraw=\(launch.histogrammedTimeToFirstDraw)")
            }
            if let timeMetrics = payload.applicationTimeMetrics {
                log.info("App time: cumulative=\(timeMetrics.cumulativeForegroundTime)")
            }
        }
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logHangDiagnostics(payload)
            logCrashDiagnostics(payload)
            logCPUExceptionDiagnostics(payload)
        }
    }

    // MARK: - Diagnostics

    private func logHangDiagnostics(_ payload: MXDiagnosticPayload) {
        guard let hangs = payload.hangDiagnostics, !hangs.isEmpty else { return }
        let log = Self.metricLog
        for (i, hang) in hangs.enumerated() {
            log.event(.error, item: "hang/\(i)", status: .failed,
                       detail: "duration=\(hang.hangDuration)")
            logCallStackTree(hang.callStackTree, label: "hang-\(i)", log: log)
            saveRawJSON(hang.callStackTree, type: "hang", index: i)
        }
    }

    private func logCrashDiagnostics(_ payload: MXDiagnosticPayload) {
        guard let crashes = payload.crashDiagnostics, !crashes.isEmpty else { return }
        let log = Self.metricLog
        for (i, crash) in crashes.enumerated() {
            log.event(.error, item: "crash/\(i)", status: .failed,
                       detail: "signal=\(crash.signal) type=\(crash.exceptionType?.intValue ?? -1) code=\(crash.exceptionCode?.intValue ?? -1)")
            logCallStackTree(crash.callStackTree, label: "crash-\(i)", log: log)
            saveRawJSON(crash.callStackTree, type: "crash", index: i)
        }
    }

    private func logCPUExceptionDiagnostics(_ payload: MXDiagnosticPayload) {
        guard let exceptions = payload.cpuExceptionDiagnostics, !exceptions.isEmpty else { return }
        let log = Self.metricLog
        for (i, exception) in exceptions.enumerated() {
            log.event(.error, item: "cpu-exception/\(i)", status: .failed,
                       detail: "cpuTime=\(exception.totalCPUTime) sampledTime=\(exception.totalSampledTime)")
            logCallStackTree(exception.callStackTree, label: "cpu-\(i)", log: log)
            saveRawJSON(exception.callStackTree, type: "cpu-exception", index: i)
        }
    }

    // MARK: - Call Stack Parsing

    /// Parse MXCallStackTree JSON into human-readable frames and log them.
    private func logCallStackTree(_ tree: MXCallStackTree, label: String, log: PVLogChannel) {
        let jsonData = tree.jsonRepresentation()
        guard let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let callStacks = parsed["callStacks"] as? [[String: Any]] else {
            log.warning("[\(label)] Could not parse call stack tree")
            return
        }

        for (stackIndex, stack) in callStacks.enumerated() {
            let isAttributed = stack["threadAttributed"] as? Bool ?? false
            if !isAttributed && callStacks.count > 1 { continue } // only log attributed thread for multi-thread reports

            log.info("[\(label)] Thread \(stackIndex)\(isAttributed ? " (attributed)" : ""):")

            guard let rootFrames = stack["callStackRootFrames"] as? [[String: Any]] else { continue }
            var frames: [(binary: String, offset: UInt64, address: UInt64)] = []
            flattenFrames(rootFrames, into: &frames)

            for (frameIndex, frame) in frames.prefix(30).enumerated() {
                log.info("  #\(frameIndex) \(frame.binary) +\(frame.offset) [0x\(String(frame.address, radix: 16))]")
            }
            if frames.count > 30 {
                log.info("  ... \(frames.count - 30) more frames")
            }
        }
    }

    /// Recursively flatten the nested MXCallStackTree frame structure.
    private func flattenFrames(_ frames: [[String: Any]], into result: inout [(binary: String, offset: UInt64, address: UInt64)]) {
        for frame in frames {
            let binary = frame["binaryName"] as? String ?? "??"
            let offset = frame["offsetIntoBinaryTextSegment"] as? UInt64 ?? 0
            let address = frame["address"] as? UInt64 ?? 0
            result.append((binary, offset, address))

            if let subFrames = frame["subFrames"] as? [[String: Any]] {
                flattenFrames(subFrames, into: &result)
            }
        }
    }

    // MARK: - Raw JSON Persistence

    /// Save raw call stack JSON to individual files for offline symbolication.
    /// Files go to `Documents/Logs/MetricKit/<type>-<timestamp>.json`.
    private func saveRawJSON(_ tree: MXCallStackTree, type: String, index: Int) {
        let fm = FileManager.default
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/MetricKit", isDirectory: true)

        try? fm.createDirectory(at: base, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(type)-\(timestamp)-\(index).json"
        let fileURL = base.appendingPathComponent(filename)

        let jsonData = tree.jsonRepresentation()
        try? jsonData.write(to: fileURL)
        Self.metricLog.debug("Saved raw JSON: \(filename)")
    }
}
#endif

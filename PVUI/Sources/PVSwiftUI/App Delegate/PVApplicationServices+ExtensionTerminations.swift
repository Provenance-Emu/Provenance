//
//  PVApplicationServices+ExtensionTerminations.swift
//  PVUI
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Host-app side of `ExtensionRunMarker`. App extensions are separate processes,
//  so the app's crash SDK cannot see them dying. Each instrumented extension
//  leaves a marker file in the App Group while it works and removes it on clean
//  completion; anything still there when the app next launches is an extension
//  invocation that was killed.
//
//  Reporting from the host app (rather than linking a crash SDK into every
//  extension) is deliberate: the terminations under investigation are jetsam and
//  `0xdead10cc`, both SIGKILL and therefore invisible to any in-process handler,
//  and the extensions in question are the memory-constrained ones we must not
//  make heavier.
//
//  This path is NOT gated on MetricKit (unavailable on tvOS), so any extension
//  that records a marker is reported on every platform. Spotlight is the only
//  instrumented extension today: TopShelf reads the App Group library snapshot
//  and never opens Realm, so it has no database-sized memory spike to catch.
//

import Foundation
import PVLogging
import PVSupport

#if canImport(Sentry)
import Sentry
#endif

extension PVApplicationServices {

    /// Dedicated log channel for app-extension terminations.
    static let extensionTerminationLog: PVLogChannel = {
        let channel = PVLogChannel("extensions", fileOutput: true, maxEntries: 200)
        PVLogChannelRegistry.shared.register(channel)
        return channel
    }()

    /// Consume and report every extension invocation that never finished.
    ///
    /// Call once at launch. Records are removed as they are read, so each
    /// unclean exit is reported exactly once.
    func reportPendingExtensionTerminations() {
        let records = ExtensionRunMarker.consumePendingRecords()
        let log = Self.extensionTerminationLog

        guard !records.isEmpty else {
            log.debug("No pending extension termination markers")
            return
        }

        log.warning("Found \(records.count) unclean extension termination(s)")
        for record in records {
            log.event(
                .error,
                item: "extension-termination/\(record.extensionName)",
                status: .failed,
                detail: record.summaryLine
            )
            captureExtensionTermination(record)
        }
    }

    /// Forward one termination to Sentry, tagged so jetsam can be separated
    /// from ordinary signal crashes in the dashboard.
    private func captureExtensionTermination(_ record: ExtensionRunRecord) {
#if canImport(Sentry)
        let event = Event(level: .warning)
        event.message = SentryMessage(
            formatted: "App extension terminated: \(record.extensionName) (\(record.likelyCause))"
        )
        event.tags = record.reportingTags
        event.context = [
            "extension_run": [
                "phase": record.phase,
                "duration_seconds": record.duration,
                "footprint_bytes": record.footprintBytes,
                "available_memory_bytes": record.availableMemoryBytes,
                "app_build": record.appBuildVersion
            ]
        ]
        SentrySDK.capture(event: event)
#endif
    }
}

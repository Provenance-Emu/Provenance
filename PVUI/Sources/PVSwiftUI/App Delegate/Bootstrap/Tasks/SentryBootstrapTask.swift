//
//  SentryBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-04-01.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

#if canImport(Sentry)
import Sentry
#endif

/// Configures Sentry crash reporting and performance monitoring.
///
/// Uses MetricKit-only mode (`enableCrashHandler = false`) to avoid
/// signal handler conflicts with emulator cores that use SIGSEGV/SIGBUS
/// for MMU mapping (e.g. Flycast).
///
/// Only enabled for App Store builds with official bundle identifiers.
///
/// Requires `BootstrapKey.logging` so that any errors are captured in the log.
/// Provides `BootstrapKey.crashReporting`.
struct SentryBootstrapTask: BootstrapTask {
    var name: String { "Sentry" }
    var dependencies: [String] { [BootstrapKey.logging] }
    var provisions: [String] { [BootstrapKey.crashReporting] }

    let isAppStore: Bool

    func execute() async throws {
#if canImport(Sentry)
        guard isAppStore else {
            ILOG("SentryBootstrapTask: Skipping — not an App Store build")
            return
        }

        SentrySDK.start { options in
            options.dsn = "https://f9976bad538343d59606a8ef312d4720@o199354.ingest.us.sentry.io/1309415"
            options.environment = Self.sentryEnvironment

            // CRITICAL: Do not install signal handlers — Flycast and other
            // emulator cores use SIGSEGV for MMU memory mapping interrupts.
            // Sentry will still receive crash data via MetricKit instead.
            options.enableCrashHandler = false
            options.enableMetricKit = true
            options.enableMetricKitAttachDiagnosticPayloads = true

            // App hang detection (separate from signal-based crash handler)
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 2.0

            // Performance monitoring
            options.tracesSampleRate = 0.2
            options.profilesSampleRate = 0.1
            options.enableAutoPerformanceTracing = true

            // Session tracking
            options.enableAutoSessionTracking = true
            options.maxBreadcrumbs = 100

            // Attachments for diagnostics
            options.attachScreenshot = true
            options.enableViewHierarchy = true

            // Release info
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "org.provenance-emu.provenance@\(version)+\(build)"
            }
        }

        ILOG("SentryBootstrapTask: Sentry configured (environment: \(Self.sentryEnvironment), crashHandler: OFF, metricKit: ON)")
#else
        ILOG("SentryBootstrapTask: Sentry SDK not available on this target")
#endif
    }

#if canImport(Sentry)
    private static var sentryEnvironment: String {
        #if DEBUG
        return "debug"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "production"
        #endif
    }
#endif
}

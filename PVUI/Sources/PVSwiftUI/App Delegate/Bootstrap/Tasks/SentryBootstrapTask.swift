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

    @MainActor
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

            // MetricKit integration — delivers symbolicated hang/crash/CPU diagnostics.
            // API_UNAVAILABLE(tvos, watchos)
            #if os(iOS) || targetEnvironment(macCatalyst)
            options.enableMetricKit = true
            options.enableMetricKitRawPayload = true
            #endif

            // Suppress MXCPUException warnings ONLY when the sample is
            // inside an emulator session. Apple kicks these out whenever
            // an app sustains >90s CPU in a ~160s wall window (~56%); the
            // emulator is *supposed* to do that at 60fps so reports
            // sampled inside libretro / Dolphin / Mednafen / etc. are
            // non-actionable noise that Sentry's top-frame grouping
            // shatters into 4-5 separate "issues" per real event.
            //
            // Reports sampled outside the emulator (UI thread spinning,
            // background processing, importer thrashing, etc.) ARE
            // actionable — those flow through unchanged.
            //
            // Heuristic: scan the stacktrace for any frame matching a
            // known-emulator pattern. Generic enough to catch all our
            // cores (native + thin/thick libretro) without enumerating
            // every dylib symbol.
            options.beforeSend = { event in
                guard let mechanismType = event.exceptions?.first?.mechanism?.type,
                      mechanismType == "mx_cpu_exception" else {
                    return event   // not a CPU report, always keep
                }
                let frames = event.exceptions?.first?.stacktrace?.frames ?? []
                let inEmulator = frames.contains { frame in
                    guard let fn = frame.function else { return false }
                    // Match common emulator-thread frames so we drop CPU
                    // reports that originated inside a running game,
                    // regardless of which core (native or RA wrapper).
                    return fn.contains("retro_")
                        || fn.contains("CachedInterpreter")
                        || fn.contains("JitBaseBlockCache")
                        || fn.contains("Fifo::FifoManager")
                        || fn.contains("CommandProcessor::")
                        || fn.contains("VertexManagerBase")
                        || fn.contains("PixelShaderManager")
                        || fn.contains("PowerPC::")
                        || fn.contains("FramebufferManager::Refresh")
                        || fn.contains("Mixer::MixerFifo")
                        || fn.contains("PrecisionTimer::SleepUntil")
                        || fn.contains("PVCoreObjCBridge startEmulation")
                        || fn.contains("PVThinLibretroCore")
                        || fn.contains("Mednafen::")
                        || fn.contains("MDFN_")
                        || fn.contains("PPSSPP")
                        || fn.contains("Flycast")
                        || fn.contains("dolphin")
                }
                return inEmulator ? nil : event
            }

            // App hang detection (separate from signal-based crash handler)
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 2.0

            // Performance monitoring
            options.tracesSampleRate = 0.2
            options.enableAutoPerformanceTracing = true

            // Async stacktrace stitching for Swift concurrency
            options.swiftAsyncStacktraces = true

            // Session tracking
            options.enableAutoSessionTracking = true
            options.maxBreadcrumbs = 100

            // Attachments for diagnostics
            options.attachScreenshot = true
            options.attachViewHierarchy = true

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

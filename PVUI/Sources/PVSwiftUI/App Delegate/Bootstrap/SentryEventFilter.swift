//
//  SentryEventFilter.swift
//  PVSwiftUI
//
//  Pure filtering logic for Sentry `beforeSend` — testable without the Sentry SDK.
//

import Foundation
import PVLibrary

/// Lightweight stack frame metadata extracted from a Sentry event.
public struct SentryEventFrame: Equatable, Sendable {
    public let function: String?
    public let filename: String?
    public let package: String?
    public let inApp: Bool

    public init(function: String?, filename: String?, package: String?, inApp: Bool) {
        self.function = function
        self.filename = filename
        self.package = package
        self.inApp = inApp
    }
}

/// Normalized view of a Sentry event used by `shouldReport(_:)`.
public struct SentryEventSnapshot: Equatable, Sendable {
    public let mechanismType: String?
    public let exceptionValue: String?
    public let exceptionType: String?
    public let level: String?
    public let transaction: String?
    public let requestURL: String?
    public let title: String?
    public let tags: [String: String]
    public let frames: [SentryEventFrame]

    public init(
        mechanismType: String?,
        exceptionValue: String?,
        exceptionType: String?,
        level: String?,
        transaction: String?,
        requestURL: String?,
        title: String?,
        tags: [String: String],
        frames: [SentryEventFrame]
    ) {
        self.mechanismType = mechanismType
        self.exceptionValue = exceptionValue
        self.exceptionType = exceptionType
        self.level = level
        self.transaction = transaction
        self.requestURL = requestURL
        self.title = title
        self.tags = tags
        self.frames = frames
    }
}

/// Decides whether a Sentry event should be uploaded (returns `true`) or suppressed (`false`).
public enum SentryEventFilter {

    /// Host suffixes for third-party artwork / skin CDNs — transient 5xx is not actionable.
    private static let externalArtworkCDNHostSuffixes: [String] = [
        "cdn.thegamesdb.net",
        "api.thegamesdb.net",
        "media.retroachievements.org",
        "retroachievements.org"
    ]

    /// Returns `true` when the event should be sent to Sentry; `false` to drop it.
    public static func shouldReport(_ snapshot: SentryEventSnapshot) -> Bool {
        if shouldDropHTTPClientError(snapshot) { return false }
        if shouldDropMetricKitCPUException(snapshot) { return false }
        if shouldDropMetricKitDiskWriteException(snapshot) { return false }
        if shouldDropIntentionalROMLoadFileIO(snapshot) { return false }
        if shouldDropLowSignalPerformanceInfo(snapshot) { return false }
        return true
    }

    // MARK: - HTTP failed requests (PROVENANCE-17Y)

    private static func shouldDropHTTPClientError(_ snapshot: SentryEventSnapshot) -> Bool {
        guard snapshot.mechanismType == "HTTPClientError" else { return false }

        if let urlString = resolvedRequestURL(snapshot),
           isExternalArtworkCDNHost(urlString) {
            return true
        }

        if let value = snapshot.exceptionValue,
           value.localizedCaseInsensitiveContains("status code: 5"),
           let urlString = resolvedRequestURL(snapshot),
           isExternalArtworkCDNHost(urlString) {
            return true
        }

        return false
    }

    private static func resolvedRequestURL(_ snapshot: SentryEventSnapshot) -> String? {
        if let requestURL = snapshot.requestURL { return requestURL }
        if let urlTag = snapshot.tags["url"] { return urlTag }
        return nil
    }

    private static func isExternalArtworkCDNHost(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        if externalArtworkCDNHostSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            return true
        }
        if host == "github.com" || host.hasSuffix(".github.com") {
            return true
        }
        return false
    }

    // MARK: - MetricKit CPU (PROVENANCE-12S, PROVENANCE-1AT, PROVENANCE-1AV)

    private static func shouldDropMetricKitCPUException(_ snapshot: SentryEventSnapshot) -> Bool {
        guard snapshot.mechanismType == "mx_cpu_exception" else { return false }
        return framesIndicateEmulator(snapshot.frames)
    }

    // MARK: - MetricKit disk write (PROVENANCE-1AW, PROVENANCE-13C)

    private static func shouldDropMetricKitDiskWriteException(_ snapshot: SentryEventSnapshot) -> Bool {
        guard snapshot.mechanismType == "mx_disk_write_exception" else { return false }
        if framesIndicateArtworkPipeline(snapshot.frames) { return true }
        return framesIndicateEmulator(snapshot.frames)
    }

    // MARK: - File IO on main thread during ROM load (PROVENANCE-14W)

    private static func shouldDropIntentionalROMLoadFileIO(_ snapshot: SentryEventSnapshot) -> Bool {
        let isFileIOTitle = snapshot.title?.localizedCaseInsensitiveContains("File IO on Main Thread") == true
            || snapshot.exceptionType?.localizedCaseInsensitiveContains("File IO on Main Thread") == true
        guard isFileIOTitle || snapshot.exceptionValue?.contains(".") == true else { return false }

        guard looksLikeROMFilename(snapshot.exceptionValue) else { return false }

        return framesIndicateROMLoad(snapshot.frames)
            || snapshot.transaction?.contains("PVEmulatorViewController") == true
    }

    /// Uses the same per-system extension registry as the importer (`systems.plist` → Realm cache).
    private static func looksLikeROMFilename(_ value: String?) -> Bool {
        guard let value, !value.isEmpty else { return false }
        let ext = (value as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        if PVEmulatorConfiguration.systemsFromCache(forFileExtension: ext) != nil {
            return true
        }
        return PVEmulatorConfiguration.systems(forFileExtension: ext) != nil
    }

    private static func framesIndicateROMLoad(_ frames: [SentryEventFrame]) -> Bool {
        frames.contains { frame in
            matchesAny(frame, patterns: [
                "loadFile",
                "PVEmulatorViewController",
                "createEmulator",
                "EmulatorCoreIOInterface"
            ])
        }
    }

    // MARK: - Low-signal perf info (PROVENANCE-17Q)

    private static func shouldDropLowSignalPerformanceInfo(_ snapshot: SentryEventSnapshot) -> Bool {
        guard snapshot.level == "info" else { return false }

        let combined = [
            snapshot.title,
            snapshot.exceptionValue,
            snapshot.exceptionType
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        if combined.localizedCaseInsensitiveContains("Degraded UI Performance") { return true }
        if combined.localizedCaseInsensitiveContains("Pre Runtime Init") { return true }
        return false
    }

    // MARK: - Frame heuristics

    private static func framesIndicateArtworkPipeline(_ frames: [SentryEventFrame]) -> Bool {
        frames.contains { frame in
            matchesAny(frame, patterns: [
                "ArtworkSearchQueue",
                "PVMediaCache",
                "ArtworkMatchingService",
                "FastArtworkLookupService",
                "writeImage",
                "writeData"
            ])
        }
    }

    private static func framesIndicateEmulator(_ frames: [SentryEventFrame]) -> Bool {
        frames.contains { frame in
            if matchesEmulatorFunction(frame.function) { return true }
            if matchesEmulatorPackage(frame.package) { return true }
            return false
        }
    }

    private static func matchesEmulatorFunction(_ function: String?) -> Bool {
        guard let function else { return false }
        let patterns = [
            "retro_",
            "CachedInterpreter",
            "JitBaseBlockCache",
            "Fifo::FifoManager",
            "CommandProcessor::",
            "VertexManagerBase",
            "PixelShaderManager",
            "PowerPC::",
            "FramebufferManager::Refresh",
            "Mixer::MixerFifo",
            "PrecisionTimer::SleepUntil",
            "PVCoreObjCBridge startEmulation",
            "PVThinLibretroCore",
            "Mednafen::",
            "MDFN_",
            "PPSSPP",
            "Flycast",
            "dolphin",
            "guarded_close_np",
            "guarded_pwrite_np",
            "thread_start",
            "swtch_pri",
            "tryCast",
            "mach_msg2_trap",
            "iokit_user_client_trap",
            "retro_api_version",
            "Common::ClassifyFloat"
        ]
        return patterns.contains { function.contains($0) }
    }

    private static func matchesEmulatorPackage(_ package: String?) -> Bool {
        guard let package else { return false }
        let lower = package.lowercased()
        let patterns = [
            "libretro",
            "pvcorebridgeretro",
            "flycast",
            "dolphin",
            "mednafen",
            "ppsspp",
            "stella",
            "snes9x",
            "mupen"
        ]
        return patterns.contains { lower.contains($0) }
    }

    private static func matchesAny(_ frame: SentryEventFrame, patterns: [String]) -> Bool {
        let candidates = [frame.function, frame.filename, frame.package].compactMap { $0 }
        return candidates.contains { candidate in
            patterns.contains { candidate.contains($0) }
        }
    }
}

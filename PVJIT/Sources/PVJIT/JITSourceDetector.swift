//
//  JITSourceDetector.swift
//  PVJIT
//
//  UIKit-capable JIT source detection for StikDebug and other URL-scheme-based tools.
//  Complements the file-system checks already performed inside DOLJitManager.
//  Part of issue #2795.
//
//  NOTE: URL-scheme detection via UIApplication.canOpenURL requires the scheme
//  to be listed in LSApplicationQueriesSchemes in the app's Info.plist.
//  If the scheme is not listed, canOpenURL always returns false on iOS 9+.
//  Required LSApplicationQueriesSchemes entries for this detector: "stikdebug", "altstore", "sidestore"
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation
import JITManager

/// Detects which tool is providing (or capable of providing) JIT.
///
/// Call `detect()` once after launch; it is synchronous and CPU-cheap.
@MainActor
public enum JITSourceDetector {

    /// Runs all detection heuristics and stores the result in `DOLJitManager`.
    /// Should be called after `attemptToAcquireJitOnStartup()` so file-system
    /// detection has already run and we only refine `.unknown` sources, plus `.none`
    /// once JIT has actually been acquired.
    public static func detect() {
        let manager = DOLJitManager.shared

        // Only refine; don't overwrite a confident result from the file-system pass.
        let current = manager.getJITSource()
        let hasAcquiredJit = manager.appHasAcquiredJit()
        guard current == .unknown || (current == .none && hasAcquiredJit) else { return }

        let detected = detectSource()
        if detected != .unknown {
            manager.setJITSource(detected)
        }
    }

    /// Returns the detected `JITSource` without storing it.
    /// Useful for one-shot queries (e.g., from the settings UI).
    public static func detectSource() -> JITSource {
#if targetEnvironment(simulator)
        return .system
#else
        // iOS 26+ native JIT API
        // TODO: Replace with direct import once JITAuthorizer becomes public API.
        if NSClassFromString("JITAuthorizer") != nil {
            return .system
        }

        // StikDebug — detected by custom URL scheme
        // Requires "stikdebug" in LSApplicationQueriesSchemes.
#if canImport(UIKit)
        if let url = URL(string: "stikdebug://"), UIApplication.shared.canOpenURL(url) {
            return .stikDebug
        }
#endif

        // TrollStore — file-system markers (duplicated here for standalone query path)
        let trollStorePaths = [
            "/var/mobile/Library/Application Support/TrollStore",
            "/usr/lib/TrollStore",
            "/var/containers/Bundle/TrollStore",
        ]
        if trollStorePaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            return .trollStore
        }

        // AltStore / SideStore — detected by the altstore:// or sidestore:// URL scheme.
        // Requires "altstore" / "sidestore" in LSApplicationQueriesSchemes.
#if canImport(UIKit)
        let altStoreSchemes = ["altstore://", "sidestore://"]
        for scheme in altStoreSchemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                return .altStore
            }
        }
#endif

        return .unknown
#endif
    }
}

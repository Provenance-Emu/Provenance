//
//  JITSource.swift
//  PVJIT
//
//  Identifies the origin / enabler of JIT execution.
//  Part of issue #2795.
//

import Foundation

/// Identifies how JIT was (or can be) acquired.
///
/// Detection is intentionally lightweight — no network calls are made.
/// URL-scheme checks require the corresponding scheme to be listed in the
/// app's `LSApplicationQueriesSchemes` Info.plist key; otherwise
/// `UIApplication.canOpenURL` always returns `false` on iOS 9+.
public enum JITSource: String, Sendable, Equatable, CaseIterable {

    /// AltStore / AltJIT via SideKit debugger protocol.
    case altStore = "AltStore"

    /// StikDebug — a lightweight USB-debugger companion app.
    /// Detected via the `stikdebug://` custom URL scheme.
    /// Requires `stikdebug` in `LSApplicationQueriesSchemes`.
    case stikDebug = "StikDebug"

    /// TrollStore — a persistent IPA installer that grants `get-task-allow`.
    /// Detected via known file-system paths (no URL scheme needed).
    case trollStore = "TrollStore"

    /// Native system JIT: Simulator, Developer Mode, or unrestricted entitlements (iOS 26+).
    case system = "System"

    /// JIT acquired but the specific source could not be determined.
    case unknown = "Unknown"

    /// JIT has not been acquired.
    case none = "None"

    /// Human-readable display name (same as raw value for now).
    public var displayName: String { rawValue }
}

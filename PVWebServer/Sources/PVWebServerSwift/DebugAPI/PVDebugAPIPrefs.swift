//
//  PVDebugAPIPrefs.swift
//  PVWebServer
//
//  Gate + auth policy for the `/api/debug/*` automation routes (on-device
//  App Store screenshot capture, `Scripts/capture_device_screenshots.py`).
//  Ported from iFly's `DebugAPIPrefs`: DEBUG builds always enable the API;
//  Release / App Store builds only register it when the hidden
//  Settings ▸ Advanced ▸ Developer ▸ "Debug API" toggle is on.
//
//  Plain `UserDefaults` keys (not PVSettings `Defaults.Keys`) because
//  PVWebServer sits below PVSettings in the package graph. PVSettings declares
//  matching `Defaults.Keys` with the same strings so the UI can bind to them.
//

import Foundation

public enum PVDebugAPIPrefs {
    /// Release builds only; DEBUG builds always enable the API.
    public static let enabledKey = "debugAPIEnabled"
    /// Whether HTTP Basic Auth (username `Provenance`) is required.
    public static let authEnabledKey = "debugAPIAuth"
    public static let passwordKey = "debugAPIPassword"

    /// Fixed Basic Auth username.
    public static let username = "Provenance"

    #if DEBUG
    public static let isDebugBuild = true
    #else
    public static let isDebugBuild = false
    #endif

    /// Whether the Debug API is enabled. Always on for DEBUG builds; for Release,
    /// user-configurable via the hidden Developer toggle.
    public static var isEnabled: Bool {
        isDebugBuild || UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Pure default resolution (unit-tested): an explicit user choice always
    /// wins; when the key has never been written, release builds default to
    /// requiring auth and DEBUG builds default to off (friction-free tooling).
    public static func resolvedAuthEnabled(stored: Bool?, isDebugBuild: Bool) -> Bool {
        stored ?? !isDebugBuild
    }

    /// Whether HTTP Basic Auth is required.
    public static var authEnabled: Bool {
        get {
            resolvedAuthEnabled(
                stored: UserDefaults.standard.object(forKey: authEnabledKey) as? Bool,
                isDebugBuild: isDebugBuild
            )
        }
        set { UserDefaults.standard.set(newValue, forKey: authEnabledKey) }
    }

    public static var password: String {
        UserDefaults.standard.string(forKey: passwordKey) ?? ""
    }

    /// The exact `Authorization` header value the Debug API accepts.
    public static func expectedAuthorizationHeader(password: String) -> String {
        "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }

    /// Pure authorization decision (unit-tested). Fail-CLOSED: when auth is
    /// required but no password has been configured, nothing is authorized —
    /// an enabled-but-unconfigured API must not accept mutations just because
    /// the user hasn't finished setting it up.
    public static func isAuthorized(header: String?, authEnabled: Bool, password: String) -> Bool {
        guard authEnabled else { return true }
        guard !password.isEmpty, let header else { return false }
        return header == expectedAuthorizationHeader(password: password)
    }
}

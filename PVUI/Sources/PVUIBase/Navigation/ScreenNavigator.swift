//
//  ScreenNavigator.swift
//  PVUIBase
//
//  Created by Provenance Emu on 2026-03-06.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provides programmatic deep-link navigation for UITests and automation.
//  Handles provenance://screen/... and provenance://debug/... URL routes.
//

import Foundation
import Combine
import PVLogging

/// A navigation destination reachable via the provenance:// deep-link scheme.
///
/// URL format:
/// ```
/// provenance://screen/library              → Game Library
/// provenance://screen/settings             → Settings root
/// provenance://screen/settings/video       → Settings > Video
/// provenance://screen/settings/audio       → Settings > Audio
/// provenance://screen/settings/controller  → Settings > Controller
/// provenance://screen/settings/advanced    → Settings > Advanced
/// provenance://screen/system/<id>          → System browser for given system identifier
/// provenance://screen/game?id=<md5>        → Game Detail sheet
/// provenance://debug/snapshot?id=<name>    → Trigger named screenshot (UITest helper)
/// ```
public enum ScreenDestination: Equatable {
    case library
    case settingsRoot
    case settingsVideo
    case settingsAudio
    case settingsController
    case settingsAdvanced
    case systemBrowser(systemID: String)
    case gameDetail(md5: String)
    case snapshot(name: String)

    /// Parse a `provenance://screen/...` or `provenance://debug/...` URL into a destination.
    /// Returns `nil` if the URL does not match a known screen route.
    public static func from(url: URL) -> ScreenDestination? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              scheme.lowercased() == "provenance" else { return nil }

        let host = components.host?.lowercased() ?? ""
        let pathComponents = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        switch host {
        case "screen":
            return parseScreenPath(pathComponents, queryItems: components.queryItems)
        case "debug":
            return parseDebugPath(pathComponents, queryItems: components.queryItems)
        default:
            return nil
        }
    }

    private static func parseScreenPath(_ parts: [String], queryItems: [URLQueryItem]?) -> ScreenDestination? {
        guard let first = parts.first else { return .library }

        switch first {
        case "library":
            return .library
        case "settings":
            let sub = parts.dropFirst().first?.lowercased()
            switch sub {
            case "video":   return .settingsVideo
            case "audio":   return .settingsAudio
            case "controller": return .settingsController
            case "advanced": return .settingsAdvanced
            default:        return .settingsRoot
            }
        case "system":
            let systemID = parts.dropFirst().first ?? ""
            guard !systemID.isEmpty else { return nil }
            return .systemBrowser(systemID: systemID)
        case "game":
            let md5 = queryItems?.first(where: { $0.name == "id" })?.value ?? ""
            guard !md5.isEmpty else { return nil }
            return .gameDetail(md5: md5)
        default:
            return nil
        }
    }

    private static func parseDebugPath(_ parts: [String], queryItems: [URLQueryItem]?) -> ScreenDestination? {
        guard parts.first == "snapshot" else { return nil }
        let name = queryItems?.first(where: { $0.name == "id" })?.value ?? "unnamed"
        return .snapshot(name: name)
    }
}

/// Shared navigator that UITests and automation use to trigger screen transitions via deep links.
///
/// Observe `destination` in your root view hierarchy to respond to navigation requests:
/// ```swift
/// .onReceive(ScreenNavigator.shared.$destination) { dest in
///     guard let dest = dest else { return }
///     // Navigate to dest, then clear it
///     ScreenNavigator.shared.clear()
/// }
/// ```
@MainActor
public final class ScreenNavigator: ObservableObject {
    public static let shared = ScreenNavigator()

    @Published public private(set) var destination: ScreenDestination?

    private init() {}

    /// Navigate to a destination programmatically.
    public func navigate(to destination: ScreenDestination) {
        ILOG("ScreenNavigator: navigate to \(destination)")
        self.destination = destination
    }

    /// Clear the current pending navigation (call after the navigation has been handled).
    public func clear() {
        destination = nil
    }

    /// Attempt to handle a `provenance://screen/...` or `provenance://debug/...` URL.
    /// - Returns: `true` if the URL matched a screen route and navigation was triggered.
    @discardableResult
    public func handle(url: URL) -> Bool {
        guard let dest = ScreenDestination.from(url: url) else { return false }
        navigate(to: dest)
        return true
    }
}

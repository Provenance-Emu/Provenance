//
//  EcosystemApp.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Models for third-party ecosystem app integration.
//  Supports launching games in XeniOS (Xbox 360), MeloNX (Switch),
//  and querying their game libraries via deep links.
//
//  Integration pattern discovered from Manic EMU's open-source implementation:
//  https://github.com/Manic-EMU/ManicEMU
//

import Foundation
#if canImport(UIKit) && !os(tvOS)
import UIKit
#endif

// MARK: - EcosystemApp

/// Ecosystem emulator apps that support cross-app game library integration.
///
/// These apps use a URL-scheme deep-link protocol to share game lists and
/// accept launch requests. Unlike `KnownEmulator`, these apps run games natively
/// and are not migration targets — they are complementary emulators that handle
/// systems Provenance doesn't (Xbox 360, Nintendo Switch, Wii U).
public enum EcosystemApp: String, CaseIterable, Codable, Sendable {

    /// XeniOS — Xbox 360 emulator for iOS/macOS.
    /// URL scheme: `xenios`  GitHub: https://github.com/xenios-jp/XeniOS
    case xenios = "xenios"

    /// MeloNX — Nintendo Switch emulator for iOS.
    /// URL scheme: `atariemulator` (intentionally obfuscated for App Store compliance).
    /// Game IDs use the standard Nintendo title-ID format (16 hex chars).
    case melonx = "atariemulator"

    /// MeloCafe — Wii U emulator for iOS.
    /// TODO: URL scheme and bundle ID not yet confirmed from public sources.
    case meloCafe = "melocafe"

    // MARK: - Display

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .xenios:   return "XeniOS"
        case .melonx:   return "MeloNX"
        case .meloCafe: return "MeloCafe"
        }
    }

    /// Short description of the supported platform.
    public var platformSummary: String {
        switch self {
        case .xenios:   return "Xbox 360"
        case .melonx:   return "Nintendo Switch"
        case .meloCafe: return "Wii U"
        }
    }

    /// SF Symbol name for this app's platform.
    public var symbolName: String {
        switch self {
        case .xenios:   return "gamecontroller.fill"
        case .melonx:   return "switch.2"
        case .meloCafe: return "tv.fill"
        }
    }

    // MARK: - URL Scheme

    /// The URL scheme registered by this app.
    public var urlScheme: String { rawValue }

    // MARK: - Install Detection

    /// Returns `true` if this app appears to be installed on the device.
    ///
    /// Requires the scheme to be listed in `LSApplicationQueriesSchemes` in `Info.plist`.
    /// Always returns `false` on tvOS (these apps are iOS-only).
    @MainActor
    public var isInstalled: Bool {
        guard let url = URL(string: "\(urlScheme)://") else { return false }
#if canImport(UIKit) && !os(tvOS)
        return UIApplication.shared.canOpenURL(url)
#else
        return false
#endif
    }

    // MARK: - Game Library Query

    /// Builds a URL that requests this app to send back its game library to Provenance.
    ///
    /// The responding app will call back via the Provenance custom URL scheme
    /// with a base64url-encoded JSON array of `EcosystemGameScheme` objects.
    ///
    /// - Parameter callbackScheme: The URL scheme Provenance registers to receive the callback.
    public func gameInfoQueryURL(callbackScheme: String = "provenance") -> URL? {
        URL(string: "\(urlScheme)://gameInfo?scheme=\(callbackScheme)")
    }

    // MARK: - Game Launch

    /// Builds a deep-link URL to launch a specific game in this app.
    ///
    /// - Parameter titleID: The platform title ID (hex string for Switch/Xbox 360).
    public func launchURL(titleID: String) -> URL? {
        switch self {
        case .xenios:
            // xenios://launch?title-id=<hex_title_id>
            return URL(string: "\(urlScheme)://launch?title-id=\(titleID)")
        case .melonx:
            // atariemulator://game?id=<titleId>
            return URL(string: "\(urlScheme)://game?id=\(titleID)")
        case .meloCafe:
            // TODO: confirm MeloCafe launch URL format
            return URL(string: "\(urlScheme)://launch?id=\(titleID)")
        }
    }

    // MARK: - Launch in App

    /// Opens this app on the device to display the given game, if installed.
    ///
    /// - Parameters:
    ///   - titleID: Platform title ID for the game to launch.
    ///   - completion: Called with `true` if the URL was successfully opened.
    @MainActor
    public func openGame(titleID: String, completion: ((Bool) -> Void)? = nil) {
        guard let url = launchURL(titleID: titleID) else {
            completion?(false)
            return
        }
#if canImport(UIKit) && !os(tvOS)
        UIApplication.shared.open(url, options: [:]) { success in
            completion?(success)
        }
#else
        completion?(false)
#endif
    }
}

// MARK: - EcosystemGameScheme

/// A game entry returned by an ecosystem app's game-info callback.
///
/// The payload is a JSON array of these objects, base64url-encoded, delivered via
/// the Provenance URL scheme: `provenance://<source_scheme>?games=<base64url_json>`
public struct EcosystemGameScheme: Codable, Sendable, Identifiable {
    /// The game's display title.
    public let titleName: String

    /// Platform-specific title identifier (hex string for Switch/Xbox).
    public let titleId: String

    /// Developer or publisher name.
    public let developer: String?

    /// Version string.
    public let version: String?

    /// Base64-encoded icon image data, if provided.
    public let iconData: String?

    public var id: String { titleId }

    public init(titleName: String, titleId: String, developer: String? = nil,
                version: String? = nil, iconData: String? = nil) {
        self.titleName = titleName
        self.titleId = titleId
        self.developer = developer
        self.version = version
        self.iconData = iconData
    }
}

// MARK: - EcosystemCallbackParser

/// Parses the game-list callback URL from an ecosystem app.
public enum EcosystemCallbackParser {

    /// Parses an incoming `provenance://<source_scheme>?games=<base64url_json>` URL.
    ///
    /// - Returns: The source `EcosystemApp` and decoded game list, or `nil` if the URL
    ///   doesn't match the expected format.
    public static func parse(url: URL) -> (source: EcosystemApp, games: [EcosystemGameScheme])? {
        guard let scheme = url.host(percentEncoded: false),
              let source = EcosystemApp(rawValue: scheme),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let gamesParam = components.queryItems?.first(where: { $0.name == "games" })?.value
        else { return nil }

        // base64url decode: restore standard base64 padding
        var base64 = gamesParam
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let games = try? JSONDecoder().decode([EcosystemGameScheme].self, from: data)
        else { return nil }

        return (source, games)
    }
}

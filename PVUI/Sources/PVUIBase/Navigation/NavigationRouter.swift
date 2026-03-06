//
//  NavigationRouter.swift
//  PVUIBase
//
//  Created by Provenance Emu on 2026-03-06.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  A dynamic, registration-based navigation router for deep-link handling.
//
//  ## Overview
//
//  Instead of maintaining a static list of every screen, `NavigationRouter` lets each
//  module or view register a `RouteProvider` that handles the routes it owns.  When a
//  deep-link URL arrives, the router dispatches it to the most-recently registered
//  provider that can handle it — so more specific handlers naturally shadow general ones.
//
//  ## URL format
//
//  ```
//  provenance://screen/library              → Game Library
//  provenance://screen/settings             → Settings root
//  provenance://screen/settings/video       → Settings › Video
//  provenance://screen/settings/audio       → Settings › Audio
//  provenance://screen/settings/controller  → Settings › Controller
//  provenance://screen/settings/advanced    → Settings › Advanced
//  provenance://screen/system/<id>          → System browser for a given system identifier
//  provenance://screen/game?id=<md5>        → Game Detail sheet
//  provenance://debug/snapshot?id=<name>    → Trigger a named screenshot (UITest helper)
//  ```
//
//  ## Adding new routes
//
//  No changes to this file are necessary.  Implement `RouteProvider` in the module or
//  view that owns the new screen, register the provider on `.onAppear`, and unregister
//  on `.onDisappear`.
//

import Foundation
import Combine
import SwiftUI
import PVLogging

// MARK: - RouteProvider

/// A type that dynamically handles navigation for a set of deep-link URL routes.
///
/// Implement this protocol in any view or module that wants to own navigation for
/// a set of URLs without modifying a central route registry.
///
/// Conforming types **must** be class types (AnyObject) so the router can store
/// them weakly, enabling automatic cleanup when the owning view is deallocated.
///
/// ## Registration
///
/// ```swift
/// struct SettingsRootView: View {
///     @Environment(\.navigationRouter) private var router
///
///     private let provider = AppRouteProvider(name: "Settings") { route in
///         // push/present the appropriate screen for `route`
///     }
///
///     var body: some View {
///         NavigationStack { … }
///             .onAppear  { router.register(provider) }
///             .onDisappear { router.unregister(provider) }
///     }
/// }
/// ```
public protocol RouteProvider: AnyObject {
    /// A descriptive name used for logging and debugging.
    var routeProviderName: String { get }

    /// Attempt to handle a deep-link URL.
    ///
    /// - Returns: `true` if this provider handled the URL and initiated navigation.
    @MainActor
    func handleRoute(url: URL) -> Bool
}

// MARK: - NavigationRouter

/// A dynamic routing registry that dispatches deep-link URLs to registered `RouteProvider`s.
///
/// Providers are stored **weakly**, so they are cleaned up automatically when their
/// owners (typically SwiftUI views) are deallocated.  Providers are tried in
/// reverse-registration order so the most-recently registered handler wins,
/// allowing nested views to shadow parent handlers for the same route.
///
/// Inject a custom instance via the `\.navigationRouter` `EnvironmentKey` to override
/// the shared router in a subtree (e.g. in tests or preview providers).
@MainActor
public final class NavigationRouter: ObservableObject {

    /// The application-wide shared router.
    public static let shared = NavigationRouter()

    private var providers: [WeakProviderBox] = []

    public init() {}

    // MARK: - Provider Registration

    /// Register a `RouteProvider` so it receives future deep-link routing calls.
    ///
    /// Duplicate registrations are silently ignored.  Providers are stored weakly;
    /// registering the same object twice still results in a single entry.
    public func register(_ provider: any RouteProvider) {
        cleanDeadProviders()
        guard !providers.contains(where: { $0.objectIdentifier == ObjectIdentifier(provider) }) else {
            return
        }
        providers.append(WeakProviderBox(provider))
        DLOG("NavigationRouter: +'\(provider.routeProviderName)' (\(providers.count) total)")
    }

    /// Remove a previously registered provider.
    ///
    /// Calling this when a view disappears is good practice, though not strictly
    /// required — dead providers are cleaned up automatically on each `handle` call.
    public func unregister(_ provider: any RouteProvider) {
        let id = ObjectIdentifier(provider)
        providers.removeAll { $0.objectIdentifier == id || $0.isExpired }
        DLOG("NavigationRouter: -'\(provider.routeProviderName)' (\(providers.count) remaining)")
    }

    // MARK: - URL Handling

    /// Dispatch a deep-link URL to the first matching registered provider.
    ///
    /// Providers are tried in reverse-registration order (most-recently registered first),
    /// so a child view's provider will shadow its parent's for the same URL.
    ///
    /// - Returns: `true` if a provider handled the URL.
    @discardableResult
    public func handle(url: URL) -> Bool {
        cleanDeadProviders()
        ILOG("NavigationRouter: routing '\(url.absoluteString)' to \(providers.count) provider(s)")
        for box in providers.reversed() {
            guard let provider = box.provider else { continue }
            if provider.handleRoute(url: url) {
                ILOG("NavigationRouter: '\(url.absoluteString)' handled by '\(provider.routeProviderName)'")
                return true
            }
        }
        WLOG("NavigationRouter: no provider handled '\(url.absoluteString)'")
        return false
    }

    // MARK: - Snapshot / Debug

    /// Extract a snapshot name from a `provenance://debug/snapshot?id=<name>` URL.
    ///
    /// Resolved inline (without providers) so it works before any view is shown —
    /// useful for UITest harnesses that fire snapshots immediately after launch.
    public func snapshotName(from url: URL) -> String? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "provenance",
            components.host?.lowercased() == "debug",
            components.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .first.map(String.init) == "snapshot"
        else { return nil }
        return components.queryItems?.first(where: { $0.name == "id" })?.value ?? "unnamed"
    }

    // MARK: - Private

    private func cleanDeadProviders() {
        providers.removeAll(where: \.isExpired)
    }

    // MARK: - WeakProviderBox

    /// Stores a `RouteProvider` weakly using a separate AnyObject reference.
    private final class WeakProviderBox {
        private(set) weak var weakObject: AnyObject?
        let objectIdentifier: ObjectIdentifier
        /// The name captured at registration time so we can log even after dealloc.
        let capturedName: String

        var provider: (any RouteProvider)? { weakObject as? any RouteProvider }
        var isExpired: Bool { weakObject == nil }

        init(_ provider: any RouteProvider) {
            self.weakObject = provider
            self.objectIdentifier = ObjectIdentifier(provider)
            self.capturedName = provider.routeProviderName
        }
    }
}

// MARK: - SwiftUI Environment

private struct NavigationRouterKey: EnvironmentKey {
    static let defaultValue: NavigationRouter = .shared
}

public extension EnvironmentValues {
    /// The `NavigationRouter` for deep-link handling in this view subtree.
    ///
    /// The default value is `NavigationRouter.shared`.  Override in tests or
    /// preview providers by injecting a custom instance:
    ///
    /// ```swift
    /// MyView()
    ///     .environment(\.navigationRouter, NavigationRouter())
    /// ```
    var navigationRouter: NavigationRouter {
        get { self[NavigationRouterKey.self] }
        set { self[NavigationRouterKey.self] = newValue }
    }
}

public extension View {
    /// Injects a `NavigationRouter` into the view's SwiftUI environment.
    func navigationRouter(_ router: NavigationRouter) -> some View {
        environment(\.navigationRouter, router)
    }
}

// MARK: - Built-in Route Parsing (AppRoute)

/// A parsed representation of the standard `provenance://screen/…` deep-link URLs.
///
/// `AppRoute` covers the screens that are built into Provenance's core navigation.
/// New screens outside this set should define their own route type and a corresponding
/// `RouteProvider` implementation — no changes here are required.
public enum AppRoute: Hashable, CustomStringConvertible, Sendable {
    case library
    case settingsRoot
    case settingsVideo
    case settingsAudio
    case settingsController
    case settingsAdvanced
    case systemBrowser(systemID: String)
    case gameDetail(md5: String)

    /// Parse a `provenance://screen/…` URL into an `AppRoute`.
    ///
    /// Returns `nil` when the URL does not match any built-in screen route.
    public static func from(url: URL) -> AppRoute? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "provenance",
            components.host?.lowercased() == "screen"
        else { return nil }

        let parts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard let first = parts.first else { return .library }

        switch first {
        case "library":
            return .library

        case "settings":
            switch parts.dropFirst().first?.lowercased() {
            case "video":       return .settingsVideo
            case "audio":       return .settingsAudio
            case "controller":  return .settingsController
            case "advanced":    return .settingsAdvanced
            default:            return .settingsRoot
            }

        case "system":
            let id = parts.dropFirst().first ?? ""
            return id.isEmpty ? nil : .systemBrowser(systemID: id)

        case "game":
            let md5 = components.queryItems?.first(where: { $0.name == "id" })?.value ?? ""
            return md5.isEmpty ? nil : .gameDetail(md5: md5)

        default:
            return nil
        }
    }

    public var description: String {
        switch self {
        case .library:                  return "library"
        case .settingsRoot:             return "settings"
        case .settingsVideo:            return "settings/video"
        case .settingsAudio:            return "settings/audio"
        case .settingsController:       return "settings/controller"
        case .settingsAdvanced:         return "settings/advanced"
        case .systemBrowser(let id):    return "system/\(id)"
        case .gameDetail(let md5):      return "game?id=\(md5)"
        }
    }
}

// MARK: - AppRouteProvider

/// A `RouteProvider` that handles the built-in `provenance://screen/…` deep links
/// by calling a handler closure with the parsed `AppRoute`.
///
/// Instantiate one per navigation context (e.g. each root `NavigationStack`)
/// and register it when the view appears:
///
/// ```swift
/// struct HomeView: View {
///     @Environment(\.navigationRouter) private var router
///     @State private var showSettings = false
///
///     // Capture navigation state in the provider's handler.
///     // Use `AppRouteProvider` as a @StateObject or let to avoid recreating it.
///     private let routeProvider: AppRouteProvider
///
///     init() {
///         routeProvider = AppRouteProvider(name: "Home") { [/* state bindings */] route in
///             switch route {
///             case .settingsRoot: showSettings = true
///             default: break
///             }
///         }
///     }
///
///     var body: some View {
///         NavigationStack { … }
///             .onAppear  { router.register(routeProvider) }
///             .onDisappear { router.unregister(routeProvider) }
///             .sheet(isPresented: $showSettings) { SettingsView() }
///     }
/// }
/// ```
public final class AppRouteProvider: RouteProvider {
    public let routeProviderName: String
    private let handler: @MainActor (AppRoute) -> Void

    /// - Parameters:
    ///   - name: Descriptive label for logging (default: `"AppRouteProvider"`).
    ///   - handler: Closure invoked on the main actor with the parsed `AppRoute`.
    public init(name: String = "AppRouteProvider",
                handler: @escaping @MainActor (AppRoute) -> Void) {
        self.routeProviderName = name
        self.handler = handler
    }

    @MainActor
    public func handleRoute(url: URL) -> Bool {
        guard let route = AppRoute.from(url: url) else { return false }
        handler(route)
        return true
    }
}

//
//  LibraryNavigator.swift
//  PVUIBase
//
//  Created by Provenance Emu on 2026-03-12.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  A typed, DRY routing hub for library-level UI actions.
//
//  ## Overview
//
//  Previously, `AppState.pendingSearchQuery` was observed directly by every
//  library-UI variant (`ConsolesWrapperView`, `RetroMainView`, `HomeView`, etc.),
//  leading to duplicated `onReceive` logic scattered across three separate view
//  hierarchies.
//
//  `LibraryNavigator` centralises this into a single `ObservableObject`:
//  - It bridges `AppState.pendingSearchQuery` → `LibraryAction.search(query:)`.
//  - It accepts programmatic dispatches for any `LibraryAction`.
//  - It can be driven by `provenance://screen/search?q=<query>` deep links via
//    `AppRoute.search` and a `LibraryRouteProvider` that is automatically registered
//    with `NavigationRouter.shared` when this navigator is first accessed.
//  - Each UI variant registers one `onReceive(LibraryNavigator.shared.$pendingAction)`
//    to perform its own response (tab-switch or search-text population).
//
//  ## Adding new library actions
//
//  1. Add a case to `LibraryAction`.
//  2. Add a helper method on `LibraryNavigator` if desired.
//  3. Add the corresponding URL parsing in `AppRoute` (NavigationRouter.swift).
//  4. Have interested views handle the new case in their `onReceive` subscriber.
//

import Foundation
import Combine
import SwiftUI
import PVLogging

// MARK: - LibraryAction

/// A typed, first-class library-level navigation action.
///
/// All library UI variants (`ConsolesWrapperView`, `RetroMainView`,
/// `RetroGameLibraryView`, `TVMediaMainView`, …) observe `LibraryNavigator`
/// and respond to these actions.
public enum LibraryAction: Equatable, Sendable {

    /// Activate in-app search pre-populated with `query`.
    /// Typically originates from a Siri "Search in App" handoff or a
    /// `provenance://screen/search?q=<query>` deep link.
    case search(query: String)

    /// Navigate to (and highlight) a specific console/system tab.
    /// Useful for deep-linking directly into a system's game list.
    case console(systemID: String)

    /// Open a game detail sheet for the game identified by `md5`.
    case game(md5: String)
}

// MARK: - LibraryNavigator

/// Centralised routing hub for library-level UI actions.
///
/// Replaces the scattered `AppState.pendingSearchQuery` observation pattern
/// with a typed, DRY dispatch that all library UI variants can subscribe to.
///
/// ### Typical view usage
///
/// ```swift
/// // Tab-switcher (ConsolesWrapperView, RetroMainView):
/// .onAppear {
///     if case .search = LibraryNavigator.shared.pendingAction {
///         switchToLibraryTab()
///     }
/// }
/// .onReceive(LibraryNavigator.shared.$pendingAction) { action in
///     if case .search = action { switchToLibraryTab() }
/// }
///
/// // Search-field consumer (HomeView, RetroGameLibraryView):
/// .onAppear {
///     LibraryNavigator.shared.consumeSearch { query in
///         searchText = query
///         isSearchBarVisible = true
///     }
/// }
/// .onReceive(LibraryNavigator.shared.$pendingAction) { action in
///     LibraryNavigator.shared.consumeSearch { query in
///         searchText = query
///         isSearchBarVisible = true
///     }
/// }
/// ```
@MainActor
public final class LibraryNavigator: ObservableObject {

    /// The application-wide shared navigator.
    public static let shared = LibraryNavigator()

    /// The currently pending library action.
    ///
    /// - Non-nil means an action is waiting to be handled.
    /// - Call `clearPendingAction()` after your view has responded to it.
    /// - Tab-switching views should NOT clear it; only the final consumer
    ///   (the view that populates the search field or shows game detail) should.
    @Published public private(set) var pendingAction: LibraryAction?

    /// A long-lived `LibraryRouteProvider` registered with `NavigationRouter.shared` once at
    /// initialization time. This enables `provenance://screen/search?q=…` deep links to be
    /// forwarded to this navigator without requiring per-view registration.
    public static let routeProvider = LibraryRouteProvider(name: "LibraryNavigator.routeProvider")

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Register with NavigationRouter so provenance://screen/search?q=... deep links
        // are forwarded to this navigator even before library views appear on screen.
        NavigationRouter.shared.register(Self.routeProvider)

        // Bridge the legacy AppState.pendingSearchQuery → .search(query:) action.
        //
        // @Published uses CurrentValueSubject semantics, so the subscriber fires
        // immediately with the *current* value on subscription — meaning a query
        // set before LibraryNavigator.shared was first accessed is still handled.
        AppState.shared.$pendingSearchQuery
            .sink { [weak self] query in
                guard let query, !query.isEmpty else { return }
                Task { @MainActor [weak self] in
                    self?.dispatch(.search(query: query))
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Dispatch

    /// Dispatch a library action to all observing views.
    ///
    /// Calling this replaces any previously unhandled action.  Views observe
    /// `$pendingAction` via `onReceive`; the final consumer calls
    /// `clearPendingAction()` once it has responded.
    public func dispatch(_ action: LibraryAction) {
        ILOG("LibraryNavigator: dispatch \(action)")
        pendingAction = action
    }

    /// Clear the pending action once a view has handled it.
    ///
    /// Also clears `AppState.pendingSearchQuery` if the cleared action was a
    /// `.search`, so legacy observers (if any remain) see a clean state.
    public func clearPendingAction() {
        if case .search = pendingAction {
            AppState.shared.pendingSearchQuery = nil
        }
        pendingAction = nil
    }

    // MARK: - Convenience Dispatchers

    /// Dispatch a search action with the given query string.
    public func search(query: String) {
        dispatch(.search(query: query))
    }

    /// Dispatch a console navigation action.
    public func navigate(toConsole systemID: String) {
        dispatch(.console(systemID: systemID))
    }

    /// Dispatch a game detail action.
    public func navigate(toGame md5: String) {
        dispatch(.game(md5: md5))
    }

    // MARK: - Consumer Helpers

    /// If the pending action is `.search(query:)`, invoke `handler` with the
    /// query string and then clear the action.
    ///
    /// This is the canonical way for search-field views to consume the action
    /// without exposing raw `pendingAction` pattern-matching everywhere.
    ///
    /// - Parameter handler: Called with the non-empty search query if present.
    public func consumeSearch(handler: (String) -> Void) {
        guard case .search(let query) = pendingAction, !query.isEmpty else { return }
        handler(query)
        clearPendingAction()
    }
}

// MARK: - LibraryRouteProvider

/// A `RouteProvider` that translates `AppRoute.search` deep links into
/// `LibraryNavigator.dispatch(.search(query:))` calls.
///
/// Register this provider in any root view that participates in the
/// `NavigationRouter` pipeline so that `provenance://screen/search?q=<query>`
/// URLs are handled even before library views are on screen:
///
/// ```swift
/// struct ContentView: View {
///     @Environment(\.navigationRouter) private var router
///     private let libraryRouteProvider = LibraryRouteProvider()
///
///     var body: some View {
///         MainLibraryView()
///             .onAppear  { router.register(libraryRouteProvider) }
///             .onDisappear { router.unregister(libraryRouteProvider) }
///     }
/// }
/// ```
public final class LibraryRouteProvider: RouteProvider {
    public let routeProviderName: String

    public init(name: String = "LibraryRouteProvider") {
        self.routeProviderName = name
    }

    @MainActor
    public func handleRoute(url: URL) -> Bool {
        guard let route = AppRoute.from(url: url) else { return false }
        switch route {
        case .search(let query):
            LibraryNavigator.shared.dispatch(.search(query: query))
            return true
        case .systemBrowser(let id):
            LibraryNavigator.shared.dispatch(.console(systemID: id))
            return true
        case .gameDetail(let md5):
            LibraryNavigator.shared.dispatch(.game(md5: md5))
            return true
        default:
            return false
        }
    }
}

// MARK: - SwiftUI View Extension

public extension View {
    /// Register a `LibraryRouteProvider` with the given `NavigationRouter`
    /// for the lifetime this view is on screen.
    ///
    /// This is a convenience wrapper around the standard
    /// `.onAppear { router.register(…) } / .onDisappear { router.unregister(…) }` pattern.
    func libraryRouteProvider(
        _ provider: LibraryRouteProvider,
        router: NavigationRouter = .shared
    ) -> some View {
        self
            .onAppear { router.register(provider) }
            .onDisappear { router.unregister(provider) }
    }
}

//
//  NearbyNavigation.swift
//  PVSwiftUI
//
//  Navigation and controller cursor for the Nearby Libraries screens.
//
//  Every screen is built from buttons and value-based navigation links, so
//  the same rows work for touch, the tvOS focus engine and, on iOS, a
//  hardware controller. iOS has no focus engine for these screens: the
//  controller moves an app-owned cursor (plain state, never `@FocusState`)
//  through a `TVMediaCursorLayout` each screen describes.
//

#if os(iOS) || os(tvOS)
import PVUIBase
import SwiftUI

/// A screen pushed inside Nearby Libraries.
enum NearbyRoute: Hashable {
    case librarySharing
    case automaticCopies
    /// A library on the network or a content server, by `DiscoveredPeer.id`.
    case peer(id: String)
}

/// The Nearby sheet's navigation path, shared by its screens so a controller
/// can push and pop them.
@MainActor
@Observable
final class NearbyNavigator {
    var path: [NearbyRoute] = []
    /// A sheet over Nearby (Add Content Server) owns the controller while it is up.
    var isSubsheetPresented = false
    /// Closes Nearby; set by the sheet that presents it.
    @ObservationIgnored var onClose: () -> Void = {}

    func push(_ route: NearbyRoute) {
        path.append(route)
    }

    /// B: back one screen, or close Nearby from its first screen.
    func back() {
        if path.isEmpty {
            onClose()
        } else {
            path.removeLast()
        }
    }

    /// Whether the screen showing `route` (nil: the first screen) is the one on top.
    func isTopScreen(_ route: NearbyRoute?) -> Bool {
        !isSubsheetPresented && path.last == route
    }
}

/// What one controller event does to a Nearby screen.
enum NearbyCursorCommand: Equatable {
    /// Highlight `item`.
    case move(String)
    /// A was pressed on `item`.
    case activate(String)
    /// B: end text entry, else back one screen.
    case back
    case none

    /// Maps `event` to a command on `layout` with the cursor on `cursor`.
    ///
    /// A cursor that left the screen (its row went away) counts as no cursor, so A
    /// never acts on something that is not drawn.
    ///
    /// While a text field is being typed in, only B acts (it leaves the field), and nothing
    /// acts with a hardware keyboard attached: its own keys drive the controller events
    /// (Space and Return are A, F is B), so typing must not press them.
    static func resolve(
        _ event: GamepadEvent,
        layout: TVMediaCursorLayout,
        cursor: String?,
        isEditingText: Bool = false,
        isKeyboardAttached: Bool = false
    ) -> NearbyCursorCommand {
        if isEditingText {
            guard !isKeyboardAttached, case .buttonB(true) = event else { return .none }
            return .back
        }
        let current = layout.contains(cursor ?? "") ? cursor : nil
        switch event {
        case .verticalNavigation(let value, true):
            return move(TVMediaCursorDirection(verticalValue: value), layout: layout, cursor: current)
        case .horizontalNavigation(let value, true):
            return move(TVMediaCursorDirection(horizontalValue: value), layout: layout, cursor: current)
        case .buttonPress(true):
            // A with no cursor on screen only shows it: a blind press must not start a copy.
            guard let current = current else { return layout.defaultItem.map { .move($0) } ?? .none }
            return .activate(current)
        case .buttonB(true):
            return .back
        default:
            return .none
        }
    }

    private static func move(
        _ direction: TVMediaCursorDirection?,
        layout: TVMediaCursorLayout,
        cursor: String?
    ) -> NearbyCursorCommand {
        // No cursor yet: the first press shows it where the screen starts.
        guard let direction = direction else { return .none }
        guard let cursor = cursor else { return layout.defaultItem.map { .move($0) } ?? .none }
        guard case .moved(let item, _) = layout.move(from: cursor, direction) else { return .none }
        return .move(item)
    }
}

/// Cursor IDs and layouts of the Nearby screens. Pure, so the order a
/// controller walks is unit-tested.
enum NearbyCursor {
    typealias Row = TVMediaCursorLayout.Row

    // MARK: Nearby Libraries

    static let librarySharing = "nearby|sharing"
    static let automaticCopies = "nearby|automatic"
    static let addServer = "nearby|addServer"
    static let openSettings = "nearby|openSettings"

    static func peer(_ id: String) -> String { "nearby|peer|\(id)" }
    static func removeServer(_ id: String) -> String { "nearby|removeServer|\(id)" }

    /// The two settings pages, then the libraries found on the network, then each content
    /// server (open, remove) and Add Content Server, then Open Settings.
    static func home(
        peerIDs: [String],
        serverPeerIDs: [String],
        showsContentServers: Bool,
        showsOpenSettings: Bool
    ) -> TVMediaCursorLayout {
        var rows = [
            Row(id: librarySharing, items: [librarySharing]),
            Row(id: automaticCopies, items: [automaticCopies])
        ]
        rows += peerIDs.map { Row(id: peer($0), items: [peer($0)]) }
        if showsContentServers {
            rows += serverPeerIDs.map { Row(id: peer($0), items: [peer($0), removeServer($0)]) }
            rows.append(Row(id: addServer, items: [addServer]))
        }
        if showsOpenSettings {
            rows.append(Row(id: openSettings, items: [openSettings]))
        }
        return TVMediaCursorLayout(rows: rows)
    }

    // MARK: One library

    static let search = "peer|search"
    static let tryAgain = "peer|tryAgain"
    static let pair = "peer|pair"
    static let code = "peer|code"
    /// iCube shows a 6-digit pairing code.
    static let pairingCodeLength = 6
    static let submitCode = "peer|submitCode"

    static func library(_ id: String) -> String { "peer|library|\(id)" }
    static func item(_ id: String) -> String { "peer|item|\(id)" }

    /// What a library screen shows, for its layout.
    enum PeerContent: Equatable {
        case waiting
        case failed
        case needsPairing
        case enteringCode
        /// Server libraries to pick from ("" is all of them) and the games, top to bottom.
        case loaded(libraryIDs: [String], itemIDs: [String])
    }

    /// Search (only once the games are listed), then the screen's controls, one per row;
    /// a content server's libraries share one row.
    static func peerLibrary(_ content: PeerContent) -> TVMediaCursorLayout {
        switch content {
        case .waiting:
            return .empty
        case .failed:
            return TVMediaCursorLayout(rows: [Row(id: tryAgain, items: [tryAgain])])
        case .needsPairing:
            return TVMediaCursorLayout(rows: [Row(id: pair, items: [pair])])
        case .enteringCode:
            return TVMediaCursorLayout(rows: [Row(id: code, items: [code]), Row(id: submitCode, items: [submitCode])])
        case .loaded(let libraryIDs, let itemIDs):
            var rows = [Row(id: search, items: [search], isHeader: true)]
            if !libraryIDs.isEmpty {
                rows.append(Row(id: "peer|libraries", items: libraryIDs.map(library)))
            }
            rows += itemIDs.map { Row(id: item($0), items: [item($0)]) }
            return TVMediaCursorLayout(rows: rows)
        }
    }

    // MARK: Share This Library

    static let sharingSwitch = "sharing|switch"

    static func system(_ rawValue: String) -> String { "sharing|system|\(rawValue)" }
    static func grant(_ grant: String, peer: String) -> String { "sharing|grant|\(peer)|\(grant)" }
    static func removePeer(_ peer: String) -> String { "sharing|remove|\(peer)" }

    /// The switch, each system, then each trusted device as one row: its three access
    /// choices and Remove.
    static func librarySharing(systems: [String], trustedPeerIDs: [String], grants: [String]) -> TVMediaCursorLayout {
        var rows = [Row(id: sharingSwitch, items: [sharingSwitch])]
        rows += systems.map { Row(id: system($0), items: [system($0)]) }
        rows += trustedPeerIDs.map { peerID in
            Row(id: "sharing|peer|\(peerID)", items: grants.map { grant($0, peer: peerID) } + [removePeer(peerID)])
        }
        return TVMediaCursorLayout(rows: rows)
    }

    // MARK: Automatic Game Copies

    static let checkAgain = "automatic|checkAgain"
    static let stopAll = "automatic|stop"

    static func source(_ peerID: String) -> String { "automatic|source|\(peerID)" }

    /// One switch per paired iCube, then Check Again and Stop when any is on.
    static func automaticCopies(peerIDs: [String], hasEnabledSources: Bool) -> TVMediaCursorLayout {
        var rows = peerIDs.map { Row(id: source($0), items: [source($0)]) }
        if hasEnabledSources {
            rows += [Row(id: checkAgain, items: [checkAgain]), Row(id: stopAll, items: [stopAll])]
        }
        return TVMediaCursorLayout(rows: rows)
    }

    // MARK: Add Content Server

    static let address = "server|address"
    static let useToken = "server|useToken"
    static let token = "server|token"
    static let username = "server|username"
    static let password = "server|password"
    static let cancel = "server|cancel"
    static let add = "server|add"

    /// The fields top to bottom, then Cancel and Add side by side.
    static func addServer(usesToken: Bool) -> TVMediaCursorLayout {
        let fields = usesToken ? [address, useToken, token] : [address, useToken, username, password]
        let fieldRows = fields.map { Row(id: $0, items: [$0]) }
        return TVMediaCursorLayout(rows: fieldRows + [Row(id: "server|actions", items: [cancel, add])])
    }
}

// MARK: - Controller cursor

extension View {
    /// Moves `cursor` through `layout` with a controller on iOS while this screen is on top
    /// of the Nearby sheet: d-pad moves, A calls `onActivate` with the item, B calls
    /// `onBack` (by default: back one screen, or close Nearby).
    ///
    /// Does nothing on tvOS (the focus engine drives the same buttons) and where no
    /// `NearbyNavigator` is in the environment (Nearby pushed from Settings).
    func nearbyControllerCursor(
        _ layout: TVMediaCursorLayout,
        cursor: Binding<String?>,
        scope: NearbyCursorScope,
        isEditingText: Bool = false,
        onBack: (() -> Void)? = nil,
        onActivate: @escaping (String) -> Void
    ) -> some View {
        modifier(NearbyControllerCursorModifier(
            layout: layout, cursor: cursor, scope: scope, isEditingText: isEditingText,
            onBack: onBack, onActivate: onActivate
        ))
    }
}

/// Where a cursor lives, which decides when it may answer the controller.
enum NearbyCursorScope: Equatable {
    /// A screen of the navigation stack (nil: the first screen).
    case screen(NearbyRoute?)
    /// The sheet over Nearby (Add Content Server).
    case subsheet
}

private struct NearbyControllerCursorModifier: ViewModifier {
    let layout: TVMediaCursorLayout
    @Binding var cursor: String?
    let scope: NearbyCursorScope
    let isEditingText: Bool
    let onBack: (() -> Void)?
    let onActivate: (String) -> Void

    @Environment(NearbyNavigator.self) private var navigator: NearbyNavigator?

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onAppear(perform: showCursorIfNeeded)
            .onChange(of: layout) { _, newLayout in
                // Keep the cursor on something drawn when its row goes away.
                if let current = cursor, !newLayout.contains(current) {
                    cursor = newLayout.defaultItem
                }
            }
            .tvMediaOverlayControllerInput(perform: handle)
        #else
        content
        #endif
    }

    #if os(iOS)
    private var isActive: Bool {
        guard let navigator, !TVMediaOverlayProbe.isGameOnScreen, !GamepadManager.shared.isModalAlertPresented else {
            return false
        }
        switch scope {
        case .screen(let route): return navigator.isTopScreen(route)
        case .subsheet: return navigator.isSubsheetPresented
        }
    }

    private func showCursorIfNeeded() {
        guard navigator != nil, cursor == nil, GamepadManager.shared.isNavigationInputAvailable else { return }
        cursor = layout.defaultItem
    }

    private func handle(_ event: GamepadEvent) {
        guard isActive else { return }
        let command = NearbyCursorCommand.resolve(
            event, layout: layout, cursor: cursor, isEditingText: isEditingText,
            isKeyboardAttached: GamepadManager.shared.isKeyboardConnected
        )
        switch command {
        case .move(let item):
            cursor = item
        case .activate(let item):
            onActivate(item)
        case .back:
            if let onBack {
                onBack()
            } else {
                navigator?.back()
            }
        case .none:
            break
        }
    }
    #endif
}
#endif

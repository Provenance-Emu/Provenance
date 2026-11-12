// Copyright © 2026 Provenance Emu. All rights reserved.
//
// Controller navigation for the Network Play screens.
//
// tvOS drives these screens with the focus engine. iOS has none for buttons, so each screen
// describes what a controller can reach as rows of targets, and an app-owned cursor (plain
// state, never `@FocusState`) moves through them: the d-pad or left stick moves it, A runs
// the target under it and B goes back (closes the screen).
//
// Input comes from sampling every pad (`PauseMenuControllerInput`), not from
// `GamepadManager`: most of these screens open over a running game, where the shared
// handlers follow one pad and can be replaced by the core.

#if !os(watchOS)
import Combine
import SwiftUI
import PVThemes

/// One thing the controller cursor can rest on.
struct NetplayCursorTarget {
    let id: String
    /// A disabled target can hold the cursor, but A does nothing on it.
    var isEnabled = true
    let action: () -> Void
}

/// A row of targets, in the order they are drawn left to right.
struct NetplayCursorRow {
    let id: String
    /// Header controls (tabs, filters, choices above the main content): reachable, but not
    /// where the cursor starts.
    var isHeader = false
    let targets: [NetplayCursorTarget]

    /// A row holding a single target, with the target's ID.
    static func single(_ target: NetplayCursorTarget, isHeader: Bool = false) -> NetplayCursorRow {
        NetplayCursorRow(id: "row.\(target.id)", isHeader: isHeader, targets: [target])
    }
}

extension Array where Element == NetplayCursorRow {
    var cursorLayout: ControllerCursorLayout {
        ControllerCursorLayout(rows: map { row in
            ControllerCursorLayout.Row(id: row.id, items: row.targets.map(\.id), isHeader: row.isHeader)
        })
    }

    func target(_ id: String) -> NetplayCursorTarget? {
        lazy.flatMap(\.targets).first { $0.id == id }
    }
}

/// What one controller command does to a screen.
enum NetplayControllerAction: Equatable {
    /// Put the cursor on this item.
    case moveCursor(String)
    /// Run the item under the cursor.
    case activate(String)
    /// Leave the screen.
    case back
    case none

    /// Resolves `command` against the screen's `layout` and its current `cursor`.
    ///
    /// On a screen with no cursor yet (a pad connected after it opened), the first press
    /// of A or a direction shows the cursor on the screen's main item instead of running
    /// or skipping something the user cannot see.
    static func resolve(_ command: PauseMenuNavigationCommand, layout: ControllerCursorLayout, cursor: String?) -> NetplayControllerAction {
        let pressed: ControllerCursorDirection?
        switch command {
        case .back:
            return .back
        case .activate:
            pressed = nil
        case .up: pressed = .up
        case .down: pressed = .down
        case .left: pressed = .left
        case .right: pressed = .right
        // Tabs and quick save/load belong to the pause menu; these screens have neither.
        case .previousTab, .nextTab, .quickSave, .quickLoad:
            return .none
        }
        guard let cursor, layout.contains(cursor) else {
            return layout.defaultItem.map(NetplayControllerAction.moveCursor) ?? .none
        }
        guard let direction = pressed else { return .activate(cursor) }
        switch layout.move(from: cursor, direction) {
        case .moved(let item, _): return .moveCursor(item)
        case .leftEdge, .blocked: return .none
        }
    }
}

/// The Network Play screens on screen, bottom to top. Only the top one answers the controller:
/// every child is a sheet, and the screen under a sheet stays live on iOS.
struct NetplayScreenStack: Equatable {
    private(set) var screens: [UUID] = []

    var isEmpty: Bool { screens.isEmpty }

    mutating func push(_ screen: UUID) {
        screens.removeAll { $0 == screen }
        screens.append(screen)
    }

    mutating func remove(_ screen: UUID) {
        screens.removeAll { $0 == screen }
    }

    func isTop(_ screen: UUID) -> Bool {
        screens.last == screen
    }
}

#if os(iOS)
/// Reads the pads while any Network Play screen is up and hands each command to the top screen.
@MainActor
final class NetplayControllerInput {
    static let shared = NetplayControllerInput()

    /// Every command, for the screens to filter by `isTop`.
    let commands = PassthroughSubject<PauseMenuNavigationCommand, Never>()

    private let sampler = PauseMenuControllerInput()
    private var stack = NetplayScreenStack()
    private var forwarding: AnyCancellable?

    private init() {
        forwarding = sampler.commands.sink { [weak self] command in
            self?.commands.send(command)
        }
    }

    func register(_ screen: UUID) {
        stack.push(screen)
        sampler.start()
    }

    func unregister(_ screen: UUID) {
        stack.remove(screen)
        if stack.isEmpty { sampler.stop() }
    }

    func isTop(_ screen: UUID) -> Bool {
        stack.isTop(screen)
    }
}

private struct NetplayControllerNavigationModifier: ViewModifier {
    let rows: [NetplayCursorRow]
    @Binding var cursor: String?
    let isCovered: Bool
    let onBack: () -> Void

    @State private var screen = UUID()

    func body(content: Content) -> some View {
        let layout = rows.cursorLayout
        ScrollViewReader { proxy in
            content
                .onAppear {
                    NetplayControllerInput.shared.register(screen)
                    /// A cursor only where something can move it: touch users see no highlight.
                    if cursor == nil, GamepadManager.shared.isNavigationInputAvailable, let item = layout.defaultItem {
                        cursor = item
                        // After the first layout pass, so the item exists to scroll to.
                        DispatchQueue.main.async { proxy.scrollTo(item) }
                    }
                }
                .onDisappear { NetplayControllerInput.shared.unregister(screen) }
                .onChange(of: layout) { _, newLayout in
                    if cursor != nil { cursor = newLayout.validCursor(cursor) }
                }
                .onReceive(NetplayControllerInput.shared.commands) { command in
                    guard NetplayControllerInput.shared.isTop(screen), !isCovered,
                          !GamepadManager.shared.isModalAlertPresented else { return }
                    switch NetplayControllerAction.resolve(command, layout: layout, cursor: cursor) {
                    case .moveCursor(let item):
                        cursor = item
                        withAnimation(.easeOut(duration: NetplayCursorMetrics.scrollDuration)) {
                            proxy.scrollTo(item)
                        }
                    case .activate(let item):
                        if let target = rows.target(item), target.isEnabled { target.action() }
                    case .back:
                        onBack()
                    case .none:
                        break
                    }
                }
        }
    }
}
#endif

enum NetplayCursorMetrics {
    /// How long a scroll that follows the cursor takes.
    static let scrollDuration: TimeInterval = 0.2
    static let highlightWidth: CGFloat = 3
    /// How far the highlight sits outside the item.
    static let highlightOutset: CGFloat = 5
}

extension View {
    /// Makes this screen navigable with a controller on iOS (a no-op on tvOS, which has the
    /// focus engine). `rows` lists what the cursor can reach; each target's view must carry
    /// `netplayCursorItem` with the same ID. `isCovered` is true while this screen shows
    /// something that is not a Network Play screen (a Game Center sheet). B calls `onBack`.
    @ViewBuilder
    func netplayControllerNavigation(
        _ rows: [NetplayCursorRow],
        cursor: Binding<String?>,
        isCovered: Bool = false,
        onBack: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        modifier(NetplayControllerNavigationModifier(rows: rows, cursor: cursor, isCovered: isCovered, onBack: onBack))
        #else
        self
        #endif
    }

    /// A Network Play screen with nothing for the cursor, where B only closes it.
    func netplayControllerBack(_ onBack: @escaping () -> Void) -> some View {
        netplayControllerNavigation([], cursor: .constant(nil), onBack: onBack)
    }

    /// Draws the controller cursor around this view while `cursor` is `id` (iOS), and lets the
    /// screen scroll to it.
    /// A nil `id` leaves the view as it is, for a view that is a target only on some screens.
    @ViewBuilder
    func netplayCursorItem(_ id: String?, cursor: String?, cornerRadius: CGFloat = 14) -> some View {
        #if os(iOS)
        if let id {
            modifier(NetplayCursorHighlight(isOn: cursor == id, cornerRadius: cornerRadius)).id(id)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct NetplayCursorHighlight: ViewModifier {
    let isOn: Bool
    let cornerRadius: CGFloat
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content.overlay {
            if isOn {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white, lineWidth: NetplayCursorMetrics.highlightWidth)
                    .shadow(color: Color(themeManager.currentPalette.defaultTintColor), radius: 6)
                    .padding(-NetplayCursorMetrics.highlightOutset)
                    .allowsHitTesting(false)
            }
        }
    }
}
#endif
#endif

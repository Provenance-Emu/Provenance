import SwiftUI
import PVUIBase

#if os(tvOS) || os(iOS)

// SwiftUI glue for controller navigation of the tvOS-style layout on iOS.
// tvOS uses the focus engine, so every modifier here is a no-op there.

@available(tvOS 16.0, iOS 17.0, *)
extension View {
    /// Delivers controller events on iOS while one of `owners` owns input.
    ///
    /// Use this instead of subscribing to `GamepadManager` directly: it is the one place
    /// that decides whether a view may act on an event, from the owner snapshot shared by
    /// every subscriber of that event.
    @ViewBuilder
    func tvMediaControllerInput(
        _ owners: Set<TVMediaInputOwner>,
        coordinator: TVMediaFocusCoordinator?,
        perform handler: @escaping (GamepadEvent) -> Void
    ) -> some View {
        #if os(iOS)
        self.onReceive(GamepadManager.shared.eventPublisher) { event in
            guard GamepadManager.shared.isNavigationInputAvailable,
                  let coordinator,
                  owners.contains(coordinator.inputOwnerForCurrentEvent()) else { return }
            handler(event)
        }
        #else
        self
        #endif
    }

    /// Delivers controller events on iOS to a sheet or popover, which owns input while it is up.
    @ViewBuilder
    func tvMediaOverlayControllerInput(perform handler: @escaping (GamepadEvent) -> Void) -> some View {
        #if os(iOS)
        self.onReceive(GamepadManager.shared.eventPublisher) { event in
            guard GamepadManager.shared.isNavigationInputAvailable else { return }
            handler(event)
        }
        #else
        self
        #endif
    }

    /// Makes this view an item the controller cursor can rest on (iOS).
    ///
    /// `isCursor` turns true while the cursor is on `id`; draw the highlight from it.
    /// `onActivate` runs when A is pressed on it. A view with its own press handling
    /// (hold for a menu) passes nil and reads `isCursor`.
    @ViewBuilder
    func tvMediaCursorItem(
        _ id: String?,
        coordinator: TVMediaFocusCoordinator?,
        isCursor: Binding<Bool>,
        onActivate: (() -> Void)? = nil
    ) -> some View {
        #if os(iOS)
        if let coordinator, let id {
            self
                .onReceive(coordinator.contentFocus.$cursorID) { cursorID in
                    let isOnThisItem = cursorID == id
                    // Only the two items a move touches re-render.
                    if isCursor.wrappedValue != isOnThisItem {
                        isCursor.wrappedValue = isOnThisItem
                    }
                }
                .tvMediaControllerInput([.content], coordinator: coordinator) { event in
                    guard let onActivate, isCursor.wrappedValue, case .buttonPress(true) = event else { return }
                    onActivate()
                }
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Moves the controller cursor through `layout` with the d-pad (iOS).
    ///
    /// Left in the first column opens the sidebar. `onMove` gets the new item and its row,
    /// for scrolling them into view. The cursor is kept valid as the layout changes, so A
    /// works as soon as a screen shows its first item.
    @ViewBuilder
    func tvMediaCursorNavigation(
        _ layout: TVMediaCursorLayout,
        coordinator: TVMediaFocusCoordinator,
        onMove: ((_ item: String, _ row: String) -> Void)? = nil
    ) -> some View {
        #if os(iOS)
        self
            .onAppear {
                coordinator.contentFocus.adoptCursor(in: layout)
            }
            .onChange(of: layout) { _, newLayout in
                coordinator.contentFocus.adoptCursor(in: newLayout)
            }
            .tvMediaControllerInput([.content], coordinator: coordinator) { event in
                let direction: TVMediaCursorDirection?
                switch event {
                case .verticalNavigation(let value, true):
                    direction = TVMediaCursorDirection(verticalValue: value)
                case .horizontalNavigation(let value, true):
                    direction = TVMediaCursorDirection(horizontalValue: value)
                default:
                    direction = nil
                }
                guard let direction else { return }
                switch layout.move(from: coordinator.contentFocus.contentCursorID, direction) {
                case .moved(let item, let row):
                    coordinator.contentFocus.setCursor(item)
                    onMove?(item, row)
                case .leftEdge:
                    coordinator.openSidebar()
                case .blocked:
                    break
                }
            }
        #else
        self
        #endif
    }

    /// Declares the cursor items this view shows, as rows, to the enclosing `tvMediaCursorScreen` (iOS).
    ///
    /// Each shelf or grid describes itself, so the screen's layout always matches what is
    /// drawn. Apply it to a view with no cursor rows of its own inside it.
    @ViewBuilder
    func tvMediaCursorRows(_ rows: [TVMediaCursorLayout.Row]) -> some View {
        #if os(iOS)
        self.preference(key: TVMediaCursorRowsKey.self, value: rows)
        #else
        self
        #endif
    }

    /// Makes this screen navigable with a controller (iOS): collects the rows its shelves
    /// and grids declare, in view order, moves the cursor through them and scrolls it
    /// into view. Apply it around the screen's scroll view.
    ///
    /// A row whose view ID is its row ID is centred when the cursor enters it, which
    /// also brings the next lazy row into existence. An item is scrolled to by its view
    /// ID, so it must carry its cursor ID as one (`ForEach` IDs count).
    @ViewBuilder
    func tvMediaCursorScreen(coordinator: TVMediaFocusCoordinator) -> some View {
        #if os(iOS)
        modifier(TVMediaCursorScreenModifier(coordinator: coordinator))
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Rows of cursor items declared by the views of one screen, in view order.
struct TVMediaCursorRowsKey: PreferenceKey {
    static let defaultValue: [TVMediaCursorLayout.Row] = []

    static func reduce(value: inout [TVMediaCursorLayout.Row], nextValue: () -> [TVMediaCursorLayout.Row]) {
        value.append(contentsOf: nextValue())
    }
}

@available(iOS 17.0, *)
private struct TVMediaCursorScreenModifier: ViewModifier {
    let coordinator: TVMediaFocusCoordinator

    @State private var layout = TVMediaCursorLayout.empty

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onPreferenceChange(TVMediaCursorRowsKey.self) { rows in
                    let collected = TVMediaCursorLayout(rows: rows)
                    if collected != layout {
                        layout = collected
                    }
                }
                .tvMediaCursorNavigation(layout, coordinator: coordinator) { item, row in
                    withAnimation(.easeOut(duration: TVMediaCursorMetrics.scrollDuration)) {
                        proxy.scrollTo(row, anchor: .center)
                    }
                    // After the row is placed, so the two scrolls don't replace each other.
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: TVMediaCursorMetrics.scrollDuration)) {
                            proxy.scrollTo(item)
                        }
                    }
                }
        }
    }
}

/// Finds what the focus coordinator is not told about: sheets and alerts presented over
/// the library, the core and save pickers, and the running game. While any is up, the
/// library behind it must not answer the controller.
@MainActor
enum TVMediaOverlayProbe {
    static var isOverlayPresented: Bool {
        GamepadManager.shared.isModalAlertPresented || isGameOnScreen || hasPresentedViewController
    }

    /// The same test `MainView` uses to hide the library behind a running game.
    private static var isGameOnScreen: Bool {
        let scenes = SceneCoordinator.shared
        return scenes.currentScene == .emulator
            && scenes.showEmulator
            && AppState.shared.emulationUIState.currentGame != nil
    }

    private static var presentedViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .presentedViewController
    }

    private static var hasPresentedViewController: Bool {
        presentedViewController != nil
    }

    /// The controller's B press for a sheet with no controller handling of its own: goes
    /// back one screen inside the sheet, or calls `dismiss` when it shows its first screen.
    /// Does nothing while something else (an alert, another sheet) is on top of it.
    static func popOrDismissSheet(_ dismiss: () -> Void) {
        guard let sheet = presentedViewController, sheet.presentedViewController == nil else { return }
        if let navigation = firstNavigationController(in: sheet), navigation.viewControllers.count > 1 {
            navigation.popViewController(animated: true)
        } else {
            dismiss()
        }
    }

    private static func firstNavigationController(in controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        for child in controller.children {
            if let navigation = firstNavigationController(in: child) { return navigation }
        }
        return nil
    }
}
#endif

/// A binding that is true while `selection` holds `id`, for `tvMediaCursorItem` on a view
/// that draws several cursor items and keeps which one is lit in a single state value.
func tvMediaCursorBinding<ID: Equatable>(_ selection: Binding<ID?>, is id: ID) -> Binding<Bool> {
    Binding(
        get: { selection.wrappedValue == id },
        set: { isOn in
            if isOn {
                selection.wrappedValue = id
            } else if selection.wrappedValue == id {
                selection.wrappedValue = nil
            }
        }
    )
}

enum TVMediaCursorMetrics {
    /// How long a scroll that follows the cursor takes.
    static let scrollDuration: TimeInterval = 0.2
}

@available(tvOS 16.0, *)
extension TVMediaContentFocus {
    /// Keeps the cursor on an item of `layout`: where the user left it if that item is
    /// still there, else the layout's default item.
    func adoptCursor(in layout: TVMediaCursorLayout) {
        if !cursorIsDefault, let current = contentCursorID, layout.contains(current) { return }
        let target = layout.defaultItem
        if target != contentCursorID || !cursorIsDefault {
            setCursor(target, isDefault: true)
        }
    }
}

#endif

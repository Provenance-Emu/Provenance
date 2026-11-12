import SwiftUI
import Combine

#if os(tvOS) || os(iOS)

#if os(tvOS)
/// Maps tvOS move commands directly.
typealias TVMediaMoveCommandDirection = MoveCommandDirection
#else
/// Lightweight move command mirror for iOS builds.
enum TVMediaMoveCommandDirection {
    case left
    case right
    case up
    case down
}
#endif

extension View {
    /// Adds a focus section on tvOS; no-op on iOS.
    @ViewBuilder
    func tvMediaFocusSection() -> some View {
        #if os(tvOS)
        self.focusSection()
        #else
        self
        #endif
    }

    /// Adds a focus scope on tvOS; no-op on iOS.
    @ViewBuilder
    func tvMediaFocusScope(_ namespace: Namespace.ID) -> some View {
        #if os(tvOS)
        self.focusScope(namespace)
        #else
        self
        #endif
    }

    /// Sets default focus on tvOS; no-op on iOS.
    @ViewBuilder
    func tvMediaPrefersDefaultFocus(_ prefers: Bool, in namespace: Namespace.ID) -> some View {
        #if os(tvOS)
        self.prefersDefaultFocus(prefers, in: namespace)
        #else
        self
        #endif
    }

    /// Handles move commands on tvOS; no-op on iOS.
    @ViewBuilder
    func tvMediaOnMoveCommand(_ handler: @escaping (TVMediaMoveCommandDirection) -> Void) -> some View {
        #if os(tvOS)
        self.onMoveCommand(perform: handler)
        #else
        self
        #endif
    }

    /// Handles exit commands on tvOS; no-op on iOS.
    @ViewBuilder
    func tvMediaOnExitCommand(_ handler: @escaping () -> Void) -> some View {
        #if os(tvOS)
        self.onExitCommand(perform: handler)
        #else
        self
        #endif
    }

    /// Marks a control the controller cursor drives on iOS.
    ///
    /// tvOS buttons are focusable already, so this does nothing there. On iOS it keeps
    /// SwiftUI focus *off* the control: a controller moves the app-owned cursor
    /// (`TVMediaContentFocus.cursorID`) instead, and a second, invisible focus on the same
    /// buttons would answer the same presses.
    @ViewBuilder
    func tvMediaFocusable() -> some View {
        #if os(iOS)
        self.focusable(false)
        #else
        self
        #endif
    }
}


/// Modern tvOS focus coordination using best practices.
/// Key principles:
/// 1. Let the focus engine do its job - don't fight it
/// 2. Only intercept when at content edge
/// 3. Sidebar expands ONLY when explicitly navigated to
/// 4. Content and sidebar are separate focus scopes
@available(tvOS 16.0, *)
@MainActor
final class TVMediaFocusCoordinator: ObservableObject {

    enum FocusZone: Equatable {
        case content
        case sidebar
        case modal
        case alert
    }

    /// Current active focus zone
    @Published private(set) var activeZone: FocusZone = .content

    /// Sidebar expanded state - only true when sidebar has focus
    @Published private(set) var isSidebarExpanded: Bool = false {
        didSet { contentFocus.setCursorHidden(isSidebarExpanded) }
    }

    /// Whether a modal is currently presented
    @Published var isModalPresented: Bool = false

    /// Whether an alert is currently presented
    @Published var isAlertPresented: Bool = false

    /// Per-tile focus state lives in its own object: it changes on every focus move, and keeping it
    /// out of this coordinator's `objectWillChange` stops the root view (content, sidebar, overlays)
    /// from re-rendering each time a tile gains focus.
    let contentFocus = TVMediaContentFocus()

    /// Track if content can scroll left (has more items to the left)
    /// Content views should update this as focus moves
    var contentCanScrollLeft: Bool {
        contentFocus.contentCanScrollLeft
    }

    /// ID of focused item in content for edge detection
    var focusedContentID: String? {
        contentFocus.focusedContentID
    }

    /// Set of IDs that are at the left edge of their container
    private var leftEdgeItemIDs: Set<String> = []

    // MARK: - Controller input ownership (iOS)

    /// True while something this coordinator is not told about is in front: a sheet, a
    /// system-presented alert, or the running game. Set by the root view on iOS.
    var isExternalOverlayPresented: () -> Bool = { false }

    private var backInterceptor: (owner: String, handler: () -> Bool)?

    /// Lets the visible screen take the controller's B press before the shell does
    /// (leave full screen, clear a search field). `handler` returns true when it used the press.
    func setBackInterceptor(owner: String, _ handler: @escaping () -> Bool) {
        backInterceptor = (owner, handler)
    }

    /// Removes `owner`'s interceptor. A screen that disappears after the next one appeared
    /// must not remove that one's, hence the owner.
    func clearBackInterceptor(owner: String) {
        if backInterceptor?.owner == owner {
            backInterceptor = nil
        }
    }

    /// Offers the B press to the visible screen. True when it was used.
    func interceptBack() -> Bool {
        backInterceptor?.handler() ?? false
    }

    private var eventOwnerSnapshot: TVMediaInputOwner?

    /// Who owns controller input right now.
    var inputOwner: TVMediaInputOwner {
        .resolve(
            isOverlayPresented: isAlertPresented || isModalPresented || isExternalOverlayPresented(),
            isSidebarExpanded: isSidebarExpanded
        )
    }

    /// Who owned controller input when the event being delivered began.
    ///
    /// One press reaches every subscriber in turn. Without this, the first one to open or
    /// close the sidebar changes the answer for the rest, and the same press is handled
    /// twice: B opened the sidebar in the shell and closed it again in the rail. The
    /// snapshot is dropped once the main queue has finished delivering the event.
    func inputOwnerForCurrentEvent() -> TVMediaInputOwner {
        if let eventOwnerSnapshot { return eventOwnerSnapshot }
        let owner = inputOwner
        eventOwnerSnapshot = owner
        DispatchQueue.main.async { [weak self] in
            self?.eventOwnerSnapshot = nil
        }
        return owner
    }

    // MARK: - Public API

    /// Called by content when an item gains focus
    func contentItemFocused(id: String, isAtLeftEdge: Bool) {
        contentFocus.update(id: id, canScrollLeft: !isAtLeftEdge)

        if isAtLeftEdge {
            leftEdgeItemIDs.insert(id)
        }
    }

    /// Called when focus should move to sidebar
    /// Only call this when user is at the left edge of content
    func openSidebar() {
        guard !isModalPresented, !isAlertPresented else { return }
        activeZone = .sidebar
        isSidebarExpanded = true
    }

    /// Called when sidebar item is selected or user navigates right from sidebar
    func closeSidebar() {
        isSidebarExpanded = false
        activeZone = .content
    }

    /// Toggle sidebar state (for Menu button)
    func toggleSidebar() {
        if isSidebarExpanded {
            closeSidebar()
        } else {
            openSidebar()
        }
    }

    /// Called when sidebar gains focus (from focus engine)
    func sidebarGainedFocus() {
        guard !isModalPresented, !isAlertPresented else { return }
        activeZone = .sidebar
        isSidebarExpanded = true
    }

    /// Called when sidebar loses focus
    func sidebarLostFocus() {
        // Only collapse if we're not in a modal/alert
        guard activeZone == .sidebar else { return }
        isSidebarExpanded = false
        activeZone = .content
    }

    /// Check if we should allow left navigation to sidebar
    func shouldNavigateToSidebar() -> Bool {
        guard !isModalPresented, !isAlertPresented else { return false }
        guard activeZone == .content else { return false }

        // If focus isn't being tracked, be conservative and do not hijack left navigation.
        guard focusedContentID != nil else { return false }

        // Open sidebar only when the currently-focused item is at the left edge of its container.
        // `contentCanScrollLeft` is updated via `contentItemFocused(id:isAtLeftEdge:)`.
        return contentCanScrollLeft == false
    }

    /// Register an item as being at the left edge
    func registerLeftEdgeItem(_ id: String) {
        leftEdgeItemIDs.insert(id)
    }

    /// Unregister an item from left edge
    func unregisterLeftEdgeItem(_ id: String) {
        leftEdgeItemIDs.remove(id)
    }

    /// Clear all edge registrations (call when view changes)
    func clearEdgeRegistrations() {
        leftEdgeItemIDs.removeAll()
        contentFocus.update(id: nil, canScrollLeft: false)
    }

    // MARK: - Modal/Alert handling

    func setModalPresented(_ presented: Bool) {
        isModalPresented = presented
        if presented {
            activeZone = .modal
        } else {
            restoreZoneAfterOverlay()
        }
    }

    func setAlertPresented(_ presented: Bool) {
        isAlertPresented = presented
        if presented {
            activeZone = .alert
        } else {
            restoreZoneAfterOverlay()
        }
    }

    private func restoreZoneAfterOverlay() {
        if isModalPresented {
            activeZone = .modal
        } else if isAlertPresented {
            activeZone = .alert
        } else if isSidebarExpanded {
            activeZone = .sidebar
        } else {
            activeZone = .content
        }
    }

    // MARK: - Exit command

    func handleExitCommand() -> Bool {
        if isAlertPresented || isModalPresented {
            return false
        }

        if isSidebarExpanded {
            closeSidebar()
            return true
        }

        // At content - open sidebar
        openSidebar()
        return true
    }
}

// MARK: - Content Focus State

/// Which content tile is focused, observed only by the views that react to it.
@available(tvOS 16.0, *)
@MainActor
final class TVMediaContentFocus: ObservableObject {
    /// ID of focused item in content for edge detection
    @Published private(set) var focusedContentID: String?

    /// Not published: only read synchronously by `shouldNavigateToSidebar()`.
    private(set) var contentCanScrollLeft: Bool = false

    func update(id: String?, canScrollLeft: Bool) {
        contentCanScrollLeft = canScrollLeft
        // Skip redundant writes so re-syncing the same tile doesn't invalidate observers.
        if focusedContentID != id {
            focusedContentID = id
        }
    }

    // MARK: Controller cursor (iOS)

    /// The item a controller's cursor is drawn on. Nil while the sidebar has the cursor.
    @Published private(set) var cursorID: String?

    /// The item the content cursor rests on, also while it is hidden behind the sidebar.
    private(set) var contentCursorID: String?

    private var isCursorHidden = false

    /// True until the user moves the cursor: it was put on a screen's default item, and
    /// follows that default as the screen's rows arrive (a grid that loads after its header).
    private(set) var cursorIsDefault = true

    func setCursor(_ id: String?, isDefault: Bool = false) {
        contentCursorID = id
        cursorIsDefault = isDefault
        publishCursor()
    }

    func setCursorHidden(_ hidden: Bool) {
        isCursorHidden = hidden
        publishCursor()
    }

    private func publishCursor() {
        let visible = isCursorHidden ? nil : contentCursorID
        if cursorID != visible {
            cursorID = visible
        }
    }
}

@available(tvOS 16.0, *)
private struct FocusedContentChangeModifier: ViewModifier {
    @ObservedObject var contentFocus: TVMediaContentFocus
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: contentFocus.focusedContentID) { _ in action() }
    }
}

@available(tvOS 16.0, *)
extension View {
    /// Runs `action` whenever the focused content tile changes. Observes only the small
    /// focus object, so the coordinator's other state changes don't re-run this and
    /// the modified view isn't re-rendered by focus moves.
    @MainActor
    func onFocusedContentChange(of coordinator: TVMediaFocusCoordinator, perform action: @escaping () -> Void) -> some View {
        modifier(FocusedContentChangeModifier(contentFocus: coordinator.contentFocus, action: action))
    }
}

// MARK: - Environment Key

@available(tvOS 16.0, *)
struct TVMediaFocusCoordinatorKey: EnvironmentKey {
    static var defaultValue: TVMediaFocusCoordinator {
        MainActor.assumeIsolated {
            TVMediaFocusCoordinator()
        }
    }
}

@available(tvOS 16.0, *)
extension EnvironmentValues {
    var tvMediaFocusCoordinator: TVMediaFocusCoordinator {
        get { self[TVMediaFocusCoordinatorKey.self] }
        set { self[TVMediaFocusCoordinatorKey.self] = newValue }
    }
}

// MARK: - Focus-Aware Content Container

/// A container that tracks left-edge focus state and only allows sidebar navigation
/// when focus is at the leftmost item
@available(tvOS 16.0, *)
struct TVMediaFocusAwareContent<Content: View>: View {
    @ObservedObject var focusCoordinator: TVMediaFocusCoordinator
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .tvMediaFocusSection()
            .tvMediaOnMoveCommand { direction in
                handleMoveCommand(direction)
            }
            // Observe the focused child without making the scroll container a focus target.
            .onFocusedContentChange(of: focusCoordinator) {
                if focusCoordinator.focusedContentID != nil && focusCoordinator.activeZone == .sidebar {
                    focusCoordinator.sidebarLostFocus()
                }
            }
    }

    private func handleMoveCommand(_ direction: TVMediaMoveCommandDirection) {
        if direction == .left {
            // Only open sidebar if we're at the left edge
            if focusCoordinator.shouldNavigateToSidebar() {
                focusCoordinator.openSidebar()
            }
            // Otherwise, let the focus engine handle it naturally
        }
        // Other directions: do nothing, let focus engine handle
    }
}

// MARK: - Left Edge Focus Modifier

/// Modifier to mark a view as being at the left edge of a horizontal scroll
@available(tvOS 16.0, *)
struct LeftEdgeFocusModifier: ViewModifier {
    let id: String
    let isAtLeftEdge: Bool
    @ObservedObject var focusCoordinator: TVMediaFocusCoordinator

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { focused in
                if focused {
                    focusCoordinator.contentItemFocused(id: id, isAtLeftEdge: isAtLeftEdge)
                }
            }
            .onAppear {
                if isAtLeftEdge {
                    focusCoordinator.registerLeftEdgeItem(id)
                }
            }
            .onDisappear {
                focusCoordinator.unregisterLeftEdgeItem(id)
            }
    }
}

@available(tvOS 16.0, *)
extension View {
    /// Mark this view for left-edge focus tracking
    func trackLeftEdgeFocus(
        id: String,
        isAtLeftEdge: Bool,
        coordinator: TVMediaFocusCoordinator
    ) -> some View {
        modifier(LeftEdgeFocusModifier(
            id: id,
            isAtLeftEdge: isAtLeftEdge,
            focusCoordinator: coordinator
        ))
    }
}

#endif

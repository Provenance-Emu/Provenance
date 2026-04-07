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

    /// Enables focus on iOS where needed; no-op on tvOS.
    @ViewBuilder
    func tvMediaFocusable(_ enabled: Bool = true) -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            self.focusable(enabled)
        } else {
            self
        }
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
    @Published private(set) var isSidebarExpanded: Bool = false

    /// Whether a modal is currently presented
    @Published var isModalPresented: Bool = false

    /// Whether an alert is currently presented
    @Published var isAlertPresented: Bool = false

    /// Track if content can scroll left (has more items to the left)
    /// Content views should update this as focus moves
    @Published var contentCanScrollLeft: Bool = false

    /// ID of focused item in content for edge detection
    @Published var focusedContentID: String?

    /// Set of IDs that are at the left edge of their container
    private var leftEdgeItemIDs: Set<String> = []

    // MARK: - Public API

    /// Called by content when an item gains focus
    func contentItemFocused(id: String, isAtLeftEdge: Bool) {
        focusedContentID = id
        contentCanScrollLeft = !isAtLeftEdge

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
        focusedContentID = nil
        contentCanScrollLeft = false
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

    @FocusState private var isContentFocused: Bool

    var body: some View {
        content()
            .tvMediaFocusSection()
            .focused($isContentFocused)
            .tvMediaOnMoveCommand { direction in
                handleMoveCommand(direction)
            }
            .onChange(of: isContentFocused) { focused in
                if focused && focusCoordinator.activeZone == .sidebar {
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

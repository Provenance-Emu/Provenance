import Foundation
import PVUIBase

// Controller navigation for the tvOS-style layout when it runs on iOS.
//
// tvOS has the focus engine. iOS has none for this layout, so a hardware controller is
// served by an app-owned cursor: plain state that says which item is highlighted. The cursor
// math lives in PVUIBase (`ControllerCursorLayout`), shared with Network Play; these names
// are what the library code calls it.

typealias TVMediaCursorDirection = ControllerCursorDirection
typealias TVMediaCursorLayout = ControllerCursorLayout
typealias TVMediaGridMetrics = ControllerGridMetrics

/// Who a controller event belongs to.
///
/// Every subscriber of one event must get the same answer, even when one of them opens or
/// closes the sidebar while handling it: see `TVMediaFocusCoordinator.inputOwnerForCurrentEvent()`.
enum TVMediaInputOwner: Equatable, Sendable {
    /// An alert, popover, sheet or the running game is in front. It handles its own input.
    case overlay
    case sidebar
    case content

    static func resolve(isOverlayPresented: Bool, isSidebarExpanded: Bool) -> TVMediaInputOwner {
        if isOverlayPresented { return .overlay }
        return isSidebarExpanded ? .sidebar : .content
    }
}

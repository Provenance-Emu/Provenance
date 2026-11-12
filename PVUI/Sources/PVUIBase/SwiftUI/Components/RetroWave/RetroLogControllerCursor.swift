//
//  RetroLogControllerCursor.swift
//  PVUI
//
//  Where a hardware controller's cursor is in `RetroLogView` on iOS, and how the
//  d-pad and shoulder buttons move it. tvOS uses the focus engine instead.
//

import Foundation

/// A toolbar action a controller can reach in the log view, left to right as drawn.
enum RetroLogToolbarAction: CaseIterable, Equatable {
    case autoScroll
    case sortOrder
    case details
    case clear
    case fullscreen
}

/// What the controller cursor is on.
enum RetroLogControllerCursor: Equatable {
    case toolbar(RetroLogToolbarAction)
    case row(UUID)
}

enum RetroLogControllerNavigation {
    /// Rows a shoulder button jumps.
    static let pageSize = 10

    /// Moves the cursor `delta` rows down (negative: up) through `rowIDs`.
    ///
    /// Up from the first row goes to the toolbar; down from the toolbar, or with no cursor
    /// yet, goes to the first row. A row that is no longer listed restarts at the first row.
    static func moveVertical(
        from cursor: RetroLogControllerCursor?,
        by delta: Int,
        rowIDs: [UUID]
    ) -> RetroLogControllerCursor? {
        guard delta != 0 else { return cursor }
        let firstAction = RetroLogToolbarAction.allCases.first.map(RetroLogControllerCursor.toolbar)
        let firstRow = rowIDs.first.map(RetroLogControllerCursor.row)

        switch cursor {
        case .toolbar:
            return delta > 0 ? (firstRow ?? cursor) : cursor
        case .row(let id):
            guard let index = rowIDs.firstIndex(of: id) else { return firstRow ?? firstAction }
            if delta < 0, index == 0 { return firstAction }
            let target = min(max(index + delta, 0), rowIDs.count - 1)
            return .row(rowIDs[target])
        case nil:
            return delta > 0 ? (firstRow ?? firstAction) : firstAction
        }
    }

    /// Moves along the toolbar. Rows have nothing to their left or right.
    static func moveHorizontal(
        from cursor: RetroLogControllerCursor?,
        by delta: Int
    ) -> RetroLogControllerCursor? {
        guard case .toolbar(let action) = cursor else { return cursor }
        let actions = RetroLogToolbarAction.allCases
        guard let index = actions.firstIndex(of: action) else { return cursor }
        let target = min(max(index + delta, 0), actions.count - 1)
        return .toolbar(actions[target])
    }
}

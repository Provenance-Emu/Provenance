import Foundation

// Controller navigation for screens that have no focus engine: the tvOS-style layout and
// Network Play when they run on iOS.
//
// tvOS has the focus engine. iOS has none for buttons, so a hardware controller is served by
// an app-owned cursor: plain state that says which item is highlighted, moved by the pure
// functions below. Nothing here depends on SwiftUI focus.
//
// PVSwiftUI uses these through its `TVMediaCursor*` names; they live here so PVUIBase
// screens (Network Play) share the same math.

/// A direction pressed on a controller's d-pad.
public enum ControllerCursorDirection: Equatable, Sendable {
    case up // swiftlint:disable:this identifier_name
    case down
    case left
    case right

    /// Maps `GamepadManager`'s axis values: vertical is negative for down, horizontal is positive for right.
    public init?(verticalValue: Float) {
        guard verticalValue != 0 else { return nil }
        self = verticalValue < 0 ? .down : .up
    }

    public init?(horizontalValue: Float) {
        guard horizontalValue != 0 else { return nil }
        self = horizontalValue > 0 ? .right : .left
    }
}

/// The items a controller can reach on one screen, as rows of item IDs.
///
/// A shelf screen has one row per shelf, a grid has one row per line of items, and a header
/// button is a row of its own. IDs must be unique across the layout.
public struct ControllerCursorLayout: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let id: String
        public let items: [String]
        /// A row of header controls (a filter button above a grid): reachable like any
        /// other, but not where the cursor starts while the screen has other rows.
        public var isHeader: Bool

        public init(id: String, items: [String], isHeader: Bool = false) {
            self.id = id
            self.items = items
            self.isHeader = isHeader
        }
    }

    public enum Outcome: Equatable, Sendable {
        /// The cursor goes to `item`, which is in row `row`.
        case moved(item: String, row: String)
        /// Left was pressed in the first column: the sidebar is next.
        case leftEdge
        /// There is nothing in that direction.
        case blocked
    }

    /// Rows that hold at least one item, top to bottom.
    public let rows: [Row]

    public static let empty = ControllerCursorLayout(rows: [])

    public init(rows: [Row]) {
        self.rows = rows.filter { !$0.items.isEmpty }
    }

    /// A grid: `items` in reading order, `columns` to a row. Row IDs are `"<rowPrefix>-<n>"`.
    public init(gridItems items: [String], columns: Int, rowPrefix: String = "row") {
        self.init(rows: Self.gridRows(items, columns: columns, rowPrefix: rowPrefix))
    }

    /// The rows of a grid: `items` in reading order, `columns` to a row, IDs `"<rowPrefix>-<n>"`.
    public static func gridRows(_ items: [String], columns: Int, rowPrefix: String = "row") -> [Row] {
        let width = max(columns, 1)
        var rows: [Row] = []
        var start = 0
        while start < items.count {
            let end = min(start + width, items.count)
            rows.append(Row(id: "\(rowPrefix)-\(rows.count)", items: Array(items[start..<end])))
            start = end
        }
        return rows
    }

    /// This layout with `other`'s rows below it.
    public func appending(_ other: ControllerCursorLayout) -> ControllerCursorLayout {
        ControllerCursorLayout(rows: rows + other.rows)
    }

    public var isEmpty: Bool { rows.isEmpty }

    public var firstItem: String? { rows.first?.items.first }

    /// Where the cursor starts: the first item below any header rows, else the first item.
    public var defaultItem: String? {
        rows.first(where: { !$0.isHeader })?.items.first ?? firstItem
    }

    public func contains(_ item: String) -> Bool {
        position(of: item) != nil
    }

    /// The row holding `item`.
    public func rowID(of item: String) -> String? {
        position(of: item).map { rows[$0.row].id }
    }

    /// The cursor to show when a screen changes under it: `current` if it is still there, else the default item.
    public func validCursor(_ current: String?) -> String? {
        if let current, contains(current) { return current }
        return defaultItem
    }

    /// Where the cursor goes from `current` when `direction` is pressed.
    ///
    /// With no cursor yet (or one that left the screen) any press lands on the first item,
    /// so the first press is never lost. Moving up or down keeps the column where the next
    /// row is long enough, and takes its last item where it is not.
    public func move(from current: String?, _ direction: ControllerCursorDirection) -> Outcome {
        guard let first = rows.first, let firstItem = first.items.first else {
            return direction == .left ? .leftEdge : .blocked
        }
        guard let current, let position = position(of: current) else {
            return .moved(item: firstItem, row: first.id)
        }
        let row = rows[position.row]
        switch direction {
        case .left:
            guard position.column > 0 else { return .leftEdge }
            return .moved(item: row.items[position.column - 1], row: row.id)
        case .right:
            guard position.column + 1 < row.items.count else { return .blocked }
            return .moved(item: row.items[position.column + 1], row: row.id)
        case .up:
            guard position.row > 0 else { return .blocked }
            return landing(inRow: position.row - 1, column: position.column)
        case .down:
            guard position.row + 1 < rows.count else { return .blocked }
            return landing(inRow: position.row + 1, column: position.column)
        }
    }

    private func landing(inRow rowIndex: Int, column: Int) -> Outcome {
        let row = rows[rowIndex]
        let item = row.items[min(column, row.items.count - 1)]
        return .moved(item: item, row: row.id)
    }

    private func position(of item: String) -> (row: Int, column: Int)? {
        for (rowIndex, row) in rows.enumerated() {
            if let column = row.items.firstIndex(of: item) {
                return (rowIndex, column)
            }
        }
        return nil
    }
}

/// Geometry shared by the grids and the code that needs to know their shape.
public enum ControllerGridMetrics {
    /// How many columns `GridItem(.adaptive(minimum:maximum:))` lays out in `availableWidth`:
    /// as many minimum-width items as fit. The maximum only caps each item's width, it never
    /// removes a column, which is what an earlier version of this got wrong (it counted one
    /// column whenever items reached their maximum, so every item looked like a row of its own).
    public static func adaptiveColumnCount(availableWidth: CGFloat, minItemWidth: CGFloat, spacing: CGFloat) -> Int {
        guard availableWidth > 0, minItemWidth > 0 else { return 1 }
        return max(1, Int((availableWidth + spacing) / (minItemWidth + spacing)))
    }
}

//
//  PauseMenuTabs.swift
//  PVUI
//
//  The pause menu's pages, its three shapes, and the grid its controller cursor walks.
//

import CoreGraphics
import Foundation

/// A page of the pause menu's first level. The order is fixed, so a page is always in the same place.
enum PauseMenuTab: String, CaseIterable, Identifiable, Sendable {
    case game, display, controls, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .game: return String(localized: "Game")
        case .display: return String(localized: "Display")
        case .controls: return String(localized: "Controls")
        case .settings: return String(localized: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .game: return "gamecontroller"
        case .display: return "tv"
        case .controls: return "dpad"
        case .settings: return "gearshape"
        }
    }

    /// Root sections this page shows, in order. A section no page claims lands on Game,
    /// so a section added later is never lost.
    private var sectionIDs: [String] {
        switch self {
        case .game: return ["game", "statesData", "quickSettingsData", "menu"]
        case .display: return ["displayData"]
        case .controls: return ["controlsData"]
        case .settings: return ["settingsData"]
        }
    }

    /// Controls drawn in the panel's own chrome (the exit buttons and the save row),
    /// which the pages therefore leave out.
    static let chromeTileIDs: Set<String> = ["resume", "saveQuit", "quit", "saveState", "loadState", "browseSaves"]

    /// The page a root section belongs to.
    static func tab(forSectionID id: String) -> PauseMenuTab {
        allCases.first { $0.sectionIDs.contains(id) } ?? .game
    }

    /// The cells of this page, in a fixed order: its sections in their listed order, then
    /// any unclaimed ones, each keeping its own order. One grid per page, so a cell's
    /// place does not depend on how its neighbours are grouped.
    func tileIDs(inRootSections sections: [(id: String, tileIDs: [String])]) -> [String] {
        let mine = sections.filter { Self.tab(forSectionID: $0.id) == self }
        let ordered = mine.sorted { lhs, rhs in
            let left = sectionIDs.firstIndex(of: lhs.id) ?? sectionIDs.count
            let right = sectionIDs.firstIndex(of: rhs.id) ?? sectionIDs.count
            return left < right
        }
        return ordered.flatMap(\.tileIDs).filter { !Self.chromeTileIDs.contains($0) }
    }

    func next(by offset: Int) -> PauseMenuTab {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[((index + offset) % all.count + all.count) % all.count]
    }
}

/// The shape the pause panel takes for the space it has.
enum PauseMenuLayoutMode: Equatable, Sendable {
    /// Phone held upright: a sheet on the bottom edge, pages and exit buttons at the thumb.
    case sheet
    /// Phone on its side: short and wide, pages in a rail on the leading edge.
    case rail
    /// iPad, Mac and tvOS: a centred panel.
    case panel

    /// Narrower than this and taller than wide is a phone held upright.
    static let sheetMaxWidth: CGFloat = 500
    /// Shorter than this is a phone on its side.
    static let railMaxHeight: CGFloat = 500

    static func resolve(size: CGSize, isTV: Bool = false) -> PauseMenuLayoutMode {
        if isTV { return .panel }
        if size.width < sheetMaxWidth, size.height > size.width { return .sheet }
        if size.height < railMaxHeight { return .rail }
        return .panel
    }
}

/// The rows a controller cursor moves through: the panel's own controls and the grid, top to bottom.
struct PauseMenuCursorGrid: Equatable, Sendable {
    enum Direction: Sendable { case up, down, left, right }

    struct Row: Equatable, Sendable {
        let ids: [String]
        /// A grid row keeps its cells under the columns, so a short last row sits under
        /// the first cells of the row above. A chrome row spreads its controls over the width.
        let isGridRow: Bool
    }

    /// Rows of control identifiers, as drawn. Empty rows are dropped.
    let rows: [Row]
    /// Columns the grid is drawn with.
    let columns: Int
    /// Where the cursor starts: the first cell of the page, not a chrome control above it.
    let home: String?

    init(above: [[String]] = [], cells: [[String]], below: [[String]] = [], columns: Int) {
        let chrome: ([String]) -> Row = { Row(ids: $0, isGridRow: false) }
        let all = above.map(chrome) + cells.map { Row(ids: $0, isGridRow: true) } + below.map(chrome)
        rows = all.filter { !$0.ids.isEmpty }
        self.columns = max(1, columns)
        home = cells.first { !$0.isEmpty }?.first ?? rows.first?.ids.first
    }

    var ids: [String] { rows.flatMap(\.ids) }

    /// The control one step from `id`. A cursor that is nowhere, or on something no longer
    /// shown, goes home. At an edge it stays where it is.
    func move(from id: String?, _ direction: Direction) -> String? {
        guard let id, let row = rows.firstIndex(where: { $0.ids.contains(id) }),
              let column = rows[row].ids.firstIndex(of: id) else { return home }
        let current = rows[row]
        switch direction {
        case .left: return column > 0 ? current.ids[column - 1] : id
        case .right: return column < current.ids.count - 1 ? current.ids[column + 1] : id
        case .up: return row > 0 ? nearest(in: rows[row - 1], to: column, of: current) : id
        case .down: return row < rows.count - 1 ? nearest(in: rows[row + 1], to: column, of: current) : id
        }
    }

    /// Splits `ids` into rows of `columns`.
    static func chunk(_ ids: [String], columns: Int) -> [[String]] {
        guard columns > 0 else { return [ids] }
        return stride(from: 0, to: ids.count, by: columns).map { Array(ids[$0..<min($0 + columns, ids.count)]) }
    }

    /// The control of `target` under the same horizontal position as `column` of `source`.
    private func nearest(in target: Row, to column: Int, of source: Row) -> String {
        let position = (Double(column) + 0.5) / Double(slots(of: source))
        let index = min(target.ids.count - 1, max(0, Int(position * Double(slots(of: target)))))
        return target.ids[index]
    }

    /// How many equal slots a row divides the width into.
    private func slots(of row: Row) -> Int {
        row.isGridRow ? max(columns, row.ids.count) : row.ids.count
    }
}

/// Identifiers of the panel's own controls, for the cursor and for `activate`.
enum PauseMenuChromeID {
    static let quit = "chrome.quit"
    static let saveQuit = "chrome.saveQuit"
    static let resume = "chrome.resume"
    static let save = "chrome.save"
    static let load = "chrome.load"
    static let allSaves = "chrome.allSaves"
}

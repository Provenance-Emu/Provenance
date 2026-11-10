//
//  LibraryLayout.swift
//  PVUI
//

import Foundation
import PVUIBase
import SwiftUI

/// Shared layout metrics for the Home and per-console library pages.
enum LibraryLayout {
    /// Bottom inset that keeps scrolling content clear of the page-dots index.
    /// Applied once per page; don't stack it with other bottom padding.
    static let pageIndexClearance: CGFloat = 16
    static let controlHeight = RetroPauseChrome.controlHeight
    static let systemSelectorBottomGap: CGFloat = 4
    /// Space kept between the last scrollable row and the selector.
    static let systemSelectorContentGap: CGFloat = 6
    /// Room for the selector and a small gap below the last scrollable row.
    static let systemSelectorClearance = controlHeight + systemSelectorBottomGap + systemSelectorContentGap
    static let chromeBorder = RetroPauseChrome.chromeBorder
    /// Corner radius shared by the controls docked at the bottom of a library page.
    static let dockCornerRadius = RetroPauseChrome.chromeCornerRadius
    /// Horizontal inset shared by the bars above and below a library page's games.
    static let chromeHorizontalInset = RetroPauseChrome.chromeInset

    @MainActor
    static func usesCompactPhoneChrome(_ verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        AdaptiveWindowRules.usesCompactPhoneChrome(
            windowClass: AdaptiveWindow.shared.windowClass, vertical: verticalSizeClass)
    }

    static func gameCountText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 game") : String(localized: "\(count) games")
    }
}

extension View {
    /// Translucent surface for controls docked over the games: covers stay visible behind it.
    func libraryDockChrome() -> some View {
        retroChromeSurface(cornerRadius: LibraryLayout.dockCornerRadius)
    }
}

private struct LibraryBottomOverlayClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Physical bottom inset captured before the library extends its scrolling viewport.
    @Entry var libraryBottomSafeAreaInset: CGFloat = 0

    /// Extra scrollable space below the last game row for floating library controls.
    var libraryBottomOverlayClearance: CGFloat {
        get { self[LibraryBottomOverlayClearanceKey.self] }
        set { self[LibraryBottomOverlayClearanceKey.self] = newValue }
    }
}

/// Filters only the supplied page's games; navigation and global search stay independent.
enum LibraryGameFilter {
    static func games<Game>(_ games: [Game], matching query: String, title: KeyPath<Game, String>) -> [Game] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return games }
        return games.filter { $0[keyPath: title].localizedStandardContains(query) }
    }
}

/// Column count for the SwiftUI library grids.
///
/// The grid picks a column count from the width it is given, so a phone, an
/// iPad in either orientation and a resizable Mac window each get covers of a
/// sensible size instead of one fixed count stretched across all of them. The
/// user's zoom buttons then add or remove columns relative to that pick, which
/// keeps their preference meaningful when the width changes.
enum LibraryGrid {
    /// Gap between cells, and between the grid and the screen edge.
    static let spacing: CGFloat = 10

    /// How far the zoom buttons can move the column count from the automatic one.
    static let adjustmentRange = -3...8

    /// Width assumed until the grid has been measured: a phone in portrait.
    static let unmeasuredWidth: CGFloat = 390

    private static let maximumColumns = 16

    /// Cover width aimed for on a phone-width grid, giving three columns.
    private static let compactCellWidth: CGFloat = 105
    /// Cover width aimed for on an iPad-width grid — the size the artwork is
    /// laid out for, and what `DesktopLibraryMetrics.contentMaxWidth` assumes.
    private static let regularCellWidth: CGFloat = 140
    /// Grid widths the two cell sizes apply at; in between, the target grows
    /// with the width so the column count never jumps backwards.
    private static let compactWidth: CGFloat = 440
    private static let regularWidth: CGFloat = 820

    #if os(tvOS)
    /// tvOS keeps a fixed count: covers there are sized for a TV, not for
    /// density, and the focus engine wants large targets.
    private static let tvColumns = 4
    #endif

    /// Columns the grid uses at `width` before any user adjustment.
    static func automaticColumns(forWidth width: CGFloat, compactHeight: Bool = false) -> Int {
        #if os(tvOS)
        return tvColumns
        #else
        let measured = width > 0 ? width : unmeasuredWidth
        let progress = min(1, max(0, (measured - compactWidth) / (regularWidth - compactWidth)))
        let cellWidth = compactHeight ? 120 : compactCellWidth + (regularCellWidth - compactCellWidth) * progress
        let available = measured - spacing * 2
        return max(2, Int((available + spacing) / (cellWidth + spacing)))
        #endif
    }

    /// Columns to lay out at `width` with the user's `adjustment` applied.
    static func columns(forWidth width: CGFloat, adjustment: Int, compactHeight: Bool = false) -> Int {
        let clamped = min(adjustmentRange.upperBound, max(adjustmentRange.lowerBound, adjustment))
        return min(maximumColumns, max(1, automaticColumns(forWidth: width, compactHeight: compactHeight) + clamped))
    }
}

/// Reports the width a library grid is laid out in.
///
/// Whole points, written only when it changes, so this costs one update per
/// rotation or window resize rather than one per layout pass.
private struct LibraryGridWidthReader: ViewModifier {
    @Binding var width: CGFloat

    func body(content: Content) -> some View {
        content.background {
            if #available(iOS 18.0, tvOS 18.0, *) {
                Color.clear
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width.rounded()
                    } action: { newWidth in
                        update(newWidth)
                    }
            } else {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { update(geometry.size.width.rounded()) }
                        .onChange(of: geometry.size.width) { newWidth in
                            update(newWidth.rounded())
                        }
                }
            }
        }
    }

    private func update(_ newWidth: CGFloat) {
        if width != newWidth {
            width = newWidth
        }
    }
}

extension View {
    /// Tracks the width this view is laid out in, for `LibraryGrid.columns`.
    func libraryGridWidth(_ width: Binding<CGFloat>) -> some View {
        modifier(LibraryGridWidthReader(width: width))
    }
}

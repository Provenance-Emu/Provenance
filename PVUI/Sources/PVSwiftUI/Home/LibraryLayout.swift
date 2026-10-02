//
//  LibraryLayout.swift
//  PVUI
//

import SwiftUI

/// Shared layout metrics for the Home and per-console library pages.
enum LibraryLayout {
    /// Bottom inset that keeps scrolling content clear of the page-dots index.
    /// Applied once per page; don't stack it with other bottom padding.
    static let pageIndexClearance: CGFloat = 64
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

    /// Cover width aimed for on a phone-width grid, giving four columns.
    private static let compactCellWidth: CGFloat = 80
    /// Cover width aimed for on an iPad-width grid — the size the artwork is
    /// laid out for, and what `DesktopLibraryMetrics.contentMaxWidth` assumes.
    private static let regularCellWidth: CGFloat = 140
    /// Grid widths the two cell sizes apply at; in between, the target grows
    /// with the width so the column count never jumps backwards.
    private static let compactWidth: CGFloat = 430
    private static let regularWidth: CGFloat = 820

    #if os(tvOS)
    /// tvOS keeps a fixed count: covers there are sized for a TV, not for
    /// density, and the focus engine wants large targets.
    private static let tvColumns = 4
    #endif

    /// Columns the grid uses at `width` before any user adjustment.
    static func automaticColumns(forWidth width: CGFloat) -> Int {
        #if os(tvOS)
        return tvColumns
        #else
        let measured = width > 0 ? width : unmeasuredWidth
        let progress = min(1, max(0, (measured - compactWidth) / (regularWidth - compactWidth)))
        let cellWidth = compactCellWidth + (regularCellWidth - compactCellWidth) * progress
        let available = measured - spacing * 2
        return max(2, Int((available + spacing) / (cellWidth + spacing)))
        #endif
    }

    /// Columns to lay out at `width` with the user's `adjustment` applied.
    static func columns(forWidth width: CGFloat, adjustment: Int) -> Int {
        let clamped = min(adjustmentRange.upperBound, max(adjustmentRange.lowerBound, adjustment))
        return min(maximumColumns, max(1, automaticColumns(forWidth: width) + clamped))
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

//
//  DesktopLibraryMetrics.swift
//  PVUI
//
//  Layout metrics for the game library when the app runs in a desktop-sized
//  window. Companion to `PauseTilePanelMetrics`, which does the same job for
//  the in-game pause overlay.
//

import Foundation
import SwiftUI

/// Layout metrics applied to the game library only when the app is running on
/// macOS as the "Designed for iPad" build.
///
/// **Platform detection.** macOS support in this project is the iOS binary on
/// Apple Silicon. Mac Catalyst is disabled project-wide, so
/// `targetEnvironment(macCatalyst)` is dead code here and
/// `ProcessInfo.processInfo.isiOSAppOnMac` is the only runtime hook that works.
/// Because the check is a runtime value (not a `#if`), iPhone, iPad and tvOS all
/// evaluate `isDesktop == false` and every helper below collapses to identity —
/// their layout is byte-for-byte what it was before this type existed.
public enum DesktopLibraryMetrics {

    /// True when the library is being drawn inside a resizable macOS window.
    public static var isDesktop: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }

    /// Maximum width of the library's content column on a desktop window.
    ///
    /// Sized from the widest grid the library can produce: `gameLibraryScale`
    /// tops out at 8 columns, and 8 columns inside 1280pt (minus the 10pt
    /// gutters and 10pt inter-item spacing the grid already applies) lands at
    /// ~149pt per cell — the same cell size an iPad landscape grid produces,
    /// which is the density the artwork assets were tuned for. Wider than this
    /// and the grid gains no columns, it just stretches, so the column stays
    /// centered with gutters instead. `PauseTilePanelMetrics.desktopMaxWidth`
    /// (1100pt) applies the same reasoning to the pause panel.
    public static let contentMaxWidth: CGFloat = 1280

    /// Horizontal inset every band inside the content column lines up on.
    ///
    /// 10pt is not a new value: it is what the game grid, the shelf carousels and
    /// the section headers already use. Bands that picked a different inset (the
    /// Home search field at 16pt) adopt this on desktop so the column has one
    /// straight left edge instead of a ragged one. Touch layouts keep their
    /// original insets.
    public static let columnGutter: CGFloat = 10

    /// Minimum height of the display-options toolbar strip on a desktop window.
    ///
    /// On touch the strip is pinned to the 22pt icon height, which on a wide
    /// window reads as a thin empty band rather than a toolbar. 34pt is the
    /// icon height plus one 6pt step of breathing room above and below, giving
    /// the strip the same optical weight as a macOS toolbar row without
    /// changing any control's hit target.
    public static let toolbarMinHeight: CGFloat = 34

    /// Shelf row-height scale used by the Recently Played / Favorites carousels
    /// on desktop.
    ///
    /// Touch builds halve `PVRowHeight` (see `PVCompactShelfRowHeightScale`) to
    /// buy vertical space on a phone screen. That halving is what makes desktop
    /// shelf titles illegible: the title's max width is the measured artwork
    /// width, so a 75pt-tall cell yields ~50pt of artwork and clips an 11pt
    /// monospaced title to roughly five characters. A desktop window has the
    /// vertical space, so the shelves run at full `PVRowHeight` — identical to
    /// the Most Played shelf, which already ships at 1.0 everywhere.
    public static let shelfRowHeightScale: CGFloat = 1.0
}

// MARK: - View extensions

extension View {
    /// Clamps the receiver to `DesktopLibraryMetrics.contentMaxWidth` and centers
    /// it, but only on a desktop window.
    ///
    /// The non-desktop branch returns the view untouched — deliberately *not*
    /// `.frame(maxWidth: .infinity)`, which would force intrinsically-sized
    /// content to expand and would silently change iPhone/iPad/tvOS layout.
    ///
    /// Apply this to content only. Backgrounds must stay full-bleed, so keep
    /// `.background(...)` outside (above) this modifier.
    @ViewBuilder
    public func desktopLibraryContentColumn() -> some View {
        if DesktopLibraryMetrics.isDesktop {
            // Inner frame clamps the width, outer frame centers the clamped
            // column inside the full window width.
            self
                .frame(maxWidth: DesktopLibraryMetrics.contentMaxWidth)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }
}

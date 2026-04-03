//
//  RetroPauseChrome.swift
//  PVUI
//
//  Shared Retrowave chrome aligned with `PauseTileMenuView` (panel, search field, menu cell focus, section labels).
//

import SwiftUI

// MARK: - Tokens

/// Design tokens and small views that mirror `PauseTileMenuView` so the game library, continues UI, and alerts stay visually consistent.
public enum RetroPauseChrome {

    // MARK: - Radius Scale

    /// 4pt -- badges, tiny pills
    public static let radiusXS: CGFloat = 4
    /// 6pt -- search fields, buttons, small cards
    public static let radiusSM: CGFloat = 6
    /// 10pt -- sections, focus overlays, UIKit borders
    public static let radiusMD: CGFloat = 10
    /// 12pt -- alert dialogs, large overlays
    public static let radiusLG: CGFloat = 12

    /// Outer panel radius -- tighter than classic but slightly softer than search fields on larger surfaces.
    public static let panelCornerRadius: CGFloat = radiusMD

    /// Panel border stroke width.
    public static let panelStrokeLineWidth: CGFloat = 1.5

    /// Purple → pink diagonal stroke used on the pause menu panel.
    public static var panelBorderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.retroPurple.opacity(0.65), Color.retroPink.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Pause menu uses an opaque black panel; library also needs a light-theme analogue.
    public static let panelFillOpacityDark: Double = 0.88
    public static let panelFillOpacityLight: Double = 0.9

    /// `PauseTileMenuView.searchBarView` corner radii.
    public static func searchFieldCornerRadius() -> CGFloat {
        #if os(tvOS)
        return radiusMD
        #else
        return radiusSM
        #endif
    }

    public static let searchFieldFillOpacity: Double = 0.08
    public static let searchFieldStrokeOpacity: Double = 0.45
    public static let searchFieldStrokeLineWidth: CGFloat = 1

    /// Corner radii for pause menu action cells (`PauseTileMenuView` grid buttons).
    public static func menuCellCornerRadius() -> CGFloat {
        #if os(tvOS)
        return radiusMD + 2
        #else
        return radiusSM + 2
        #endif
    }

    public static let menuCellFillOpacityUnfocused: Double = 0.10
    public static let menuCellFillOpacityFocused: Double = 0.22
    public static let menuCellStrokeOpacityUnfocused: Double = 0.35
    public static let menuCellStrokeOpacityFocused: Double = 0.85
    public static let menuCellStrokeWidthUnfocused: CGFloat = 1
    public static let menuCellStrokeWidthFocused: CGFloat = 2
    public static let menuCellFocusShadowOpacity: Double = 0.5
    public static let menuCellFocusShadowRadius: CGFloat = 14

    /// Section title metrics (`PauseTileMenuView.sectionView`).
    public static func sectionTitleFontSize() -> CGFloat {
        #if os(tvOS)
        return 13
        #else
        return 9
        #endif
    }

    public static func sectionTitleTracking() -> CGFloat {
        #if os(tvOS)
        return 2.5
        #else
        return 1.5
        #endif
    }

    public static let sectionTitleMutedOpacity: Double = 0.45
}

// MARK: - Panel

/// Background shape for pause-aligned cards (toolbar strips, title bars, BIOS drawer, etc.).
public struct RetroPausePanelBackground: View {
    private let isDark: Bool

    public init(isDark: Bool) {
        self.isDark = isDark
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: RetroPauseChrome.panelCornerRadius)
            .fill(isDark ? Color.black.opacity(RetroPauseChrome.panelFillOpacityDark) : Color.white.opacity(RetroPauseChrome.panelFillOpacityLight))
            .overlay(
                RoundedRectangle(cornerRadius: RetroPauseChrome.panelCornerRadius)
                    .strokeBorder(RetroPauseChrome.panelBorderGradient, lineWidth: RetroPauseChrome.panelStrokeLineWidth)
            )
    }
}

// MARK: - Search field

/// Inner chrome for `PVSearchBar` and similar fields (`PauseTileMenuView.searchBarView`).
public struct RetroPauseSearchFieldBackground: View {
    public init() {}

    public var body: some View {
        let r = RetroPauseChrome.searchFieldCornerRadius()
        return RoundedRectangle(cornerRadius: r)
            .fill(Color.white.opacity(RetroPauseChrome.searchFieldFillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: r)
                    .strokeBorder(Color.retroCyan.opacity(RetroPauseChrome.searchFieldStrokeOpacity), lineWidth: RetroPauseChrome.searchFieldStrokeLineWidth)
            )
    }
}

/// Pause-style search chrome on dark UI; light analogue with the same cyan stroke for light game-library backgrounds.
public struct RetroPauseSearchFieldBackgroundThemed: View {
    private let isDark: Bool

    public init(isDark: Bool) {
        self.isDark = isDark
    }

    public var body: some View {
        let r = RetroPauseChrome.searchFieldCornerRadius()
        if isDark {
            RetroPauseSearchFieldBackground()
        } else {
            RoundedRectangle(cornerRadius: r)
                .fill(Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: r)
                        .strokeBorder(Color.retroCyan.opacity(RetroPauseChrome.searchFieldStrokeOpacity), lineWidth: RetroPauseChrome.searchFieldStrokeLineWidth)
                )
        }
    }
}

// MARK: - Small inset pill (e.g. game count badge)

/// Thin cyan-bordered capsule matching pause search / toggle accent lines.
public struct RetroPauseInsetPillBackground: View {
    private let isDark: Bool

    public init(isDark: Bool) {
        self.isDark = isDark
    }

    public var body: some View {
        Capsule()
            .fill(Color.white.opacity(isDark ? 0.06 : 0.12))
            .overlay(
                Capsule()
                    .strokeBorder(Color.retroCyan.opacity(0.55), lineWidth: 1)
            )
    }
}

// MARK: - View extensions

extension View {
    /// Applies `RetroPausePanelBackground` behind the view; clip to `RetroPauseChrome.panelCornerRadius` if the content should match the rounded rect.
    public func retroPausePanelBackground(isDark: Bool) -> some View {
        background {
            RetroPausePanelBackground(isDark: isDark)
        }
    }

    /// Section label typography from `PauseTileMenuView.sectionView` (caller supplies color, e.g. white or `gameLibraryText`).
    public func retroPauseSectionHeaderTypography() -> some View {
        font(.system(size: RetroPauseChrome.sectionTitleFontSize(), weight: .heavy))
            .tracking(RetroPauseChrome.sectionTitleTracking())
    }
}

//
//  SettingsLayout.swift
//  PVUI
//
//  Pure layout decisions for the iOS Settings screen, modelled on iFly's settings sidebar: which arrangement
//  a container gets (sidebar, tab strip, or the unchanged tvOS sections) and which sidebar pane each
//  `SettingsSectionTitle` lives in. No SwiftUI here, so the rules are unit-testable without a view.
//  Design note: docs/superpowers/specs/2026-10-14-settings-sidebar-design.md
//

import Foundation
import PVUIBase

// MARK: - Arrangement

/// Horizontal size class, decoupled from SwiftUI's `UserInterfaceSizeClass` so the rules stay testable.
enum SettingsWidthClass: Equatable {
    case compact
    case regular
    /// Not resolved yet (a transient `nil` size class on first render).
    case unknown
}

enum SettingsPlatform: Equatable {
    case iOS
    case tvOS

    static var current: SettingsPlatform {
        #if os(tvOS)
        return .tvOS
        #else
        return .iOS
        #endif
    }
}

/// How the Settings root lays out its panes.
enum SettingsArrangement: Equatable {
    /// Sidebar of panes on the leading edge, the selected pane's content on the right.
    case sidebar
    /// Horizontally scrolling capsule strip of panes above the selected pane's content.
    case tabStrip
    /// The tvOS layout (one long column of `TVOSSettingsSection`s), which this redesign leaves alone.
    case tvOSSections
}

enum SettingsLayoutRules {
    /// Width of the sidebar column.
    static let sidebarWidth: CGFloat = 220
    /// The content column is capped at this reading width and centred when the sidebar is shown.
    static let contentMaxWidth: CGFloat = 700
    /// A regular-width container narrower than this still gets the tab strip: below it the content beside
    /// the sidebar would be under ~380pt (e.g. an iPad form sheet).
    static let regularSidebarMinimumWidth: CGFloat = 600
    /// A compact-width container this wide gets the sidebar anyway. Every notched iPhone in landscape clears
    /// it once the safe-area insets are taken off (~724-750pt); iPhone SE landscape (667pt) does not.
    static let compactSidebarMinimumWidth: CGFloat = 700

    /// The arrangement for a settings container `containerWidth` points wide (safe area excluded).
    ///
    /// An unresolved size class falls back to the tab strip, so a transient `nil` on first render can never
    /// pick the sidebar for a phone in portrait (the iFly lesson).
    static func arrangement(
        platform: SettingsPlatform,
        widthClass: SettingsWidthClass,
        containerWidth: CGFloat
    ) -> SettingsArrangement {
        guard platform == .iOS else { return .tvOSSections }
        switch widthClass {
        case .regular:
            return containerWidth >= regularSidebarMinimumWidth ? .sidebar : .tabStrip
        case .compact:
            return containerWidth >= compactSidebarMinimumWidth ? .sidebar : .tabStrip
        case .unknown:
            return .tabStrip
        }
    }
}

// MARK: - Panes

/// One entry in the Settings sidebar / tab strip, in display order.
///
/// A pane groups `SettingsSectionTitle` sections. Every section title belongs to exactly one pane, which is
/// how a search result (`SettingsSearchEntry.section`) finds the pane to open. The legacy `SettingsTab`
/// (deep links, search index) is unchanged; `init(tab:)` maps it onto a pane.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case library
    case emulation
    case audioVideo
    case controllers
    case touchControls
    case achievements
    case advanced
    case about

    var id: String { rawValue }

    /// Label shown in the sidebar, the tab strip and search breadcrumbs.
    var title: String {
        switch self {
        case .general: return "General"
        case .library: return "Library"
        case .emulation: return "Emulation"
        case .audioVideo: return "Audio & Video"
        case .controllers: return "Controllers"
        case .touchControls: return "Touch Controls"
        case .achievements: return "RetroAchievements"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }

    /// SF Symbol for the pane.
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .library: return "books.vertical.fill"
        case .emulation: return "cpu"
        case .audioVideo: return "tv.fill"
        case .controllers: return "gamecontroller.fill"
        case .touchControls: return "hand.tap.fill"
        case .achievements: return "trophy.fill"
        case .advanced: return "wrench.and.screwdriver.fill"
        case .about: return "info.circle.fill"
        }
    }

    /// Sections shown in the pane, top to bottom. Some are compiled out on some platforms (Recording,
    /// Delta Skins); the view skips those, the model lists them so search can still place them.
    var sections: [String] {
        switch self {
        case .general:
            return [SettingsSectionTitle.app]
        case .library:
            return [SettingsSectionTitle.library, SettingsSectionTitle.libraryManagement]
        case .emulation:
            return [SettingsSectionTitle.coreOptions, SettingsSectionTitle.saves, SettingsSectionTitle.gameplayFeatures]
        case .audioVideo:
            return [SettingsSectionTitle.audio, SettingsSectionTitle.video, SettingsSectionTitle.recording]
        case .controllers:
            return [
                SettingsSectionTitle.controller,
                SettingsSectionTitle.hapticsRumble,
                SettingsSectionTitle.dualSense,
                SettingsSectionTitle.analogDeadzone
            ]
        case .touchControls:
            return [SettingsSectionTitle.onScreenControls, SettingsSectionTitle.deltaSkins]
        case .achievements:
            return [SettingsSectionTitle.retroAchievements]
        case .advanced:
            return [SettingsSectionTitle.advanced]
        case .about:
            return [
                SettingsSectionTitle.socialLinks,
                SettingsSectionTitle.documentation,
                SettingsSectionTitle.roadmap,
                SettingsSectionTitle.build,
                SettingsSectionTitle.extraInfo
            ]
        }
    }

    /// The pane holding the section titled `section`, or `nil` for an unknown title.
    init?(section: String) {
        guard let pane = Self.allCases.first(where: { $0.sections.contains(section) }) else { return nil }
        self = pane
    }

    /// The pane a legacy tab deep link (`SettingsDestination.tab`) opens: the one holding that tab's first section.
    init(tab: SettingsTab) {
        switch tab {
        case .general: self = .general
        case .emulation: self = .emulation
        case .controller: self = .controllers
        case .advanced: self = .advanced
        case .about: self = .about
        }
    }

    /// "Pane › Section" for a search result, or just the pane title when the two are the same.
    static func breadcrumb(forSection section: String) -> String {
        guard let pane = SettingsPane(section: section) else { return section }
        return pane.title == section ? pane.title : "\(pane.title) › \(section)"
    }
}

//
//  SettingsSearchIndex.swift
//  PVUI
//
//  Static, hand-maintained index of the rows shown in Settings. The rows themselves are written inline
//  in `SettingsSwiftUI.swift` (nothing declarative describes them), so this is the one place that has to
//  be updated when a user-facing setting is added, renamed or moved.
//

import Foundation
import PVUIBase

// MARK: - Section titles

/// Titles of the collapsible Settings sections.
///
/// Each value is used BOTH as the `CollapsibleSection(title:)` / tvOS section title in `SettingsSwiftUI.swift`
/// and as the `section` of the matching search entries, so the two cannot drift. The literal values are also
/// the persisted collapse key (`Defaults[.collapsedSections]`), so changing one resets users' collapse state.
enum SettingsSectionTitle {
    static let app = "App"
    static let library = "Library"
    static let libraryManagement = "Library Management"
    static let coreOptions = "Core Options"
    static let saves = "Saves"
    static let audio = "Audio"
    static let video = "Video"
    static let recording = "Recording & Streaming"
    static let retroAchievements = "RetroAchievements"
    static let controller = "Controller"
    static let hapticsRumble = "Haptics & Rumble"
    static let dualSense = "DualSense"
    static let onScreenControls = "On-Screen Controls"
    static let analogDeadzone = "Analog Deadzone"
    static let deltaSkins = "Delta Skins"
    static let socialLinks = "Social Links"
    static let documentation = "Documentation"
    static let roadmap = "Roadmap"
    static let build = "Build"
    static let extraInfo = "Extra Info"
    static let advanced = "Advanced"

    /// tvOS shows the legal / extra info rows under a section with this title instead of `extraInfo`.
    static let tvOSAbout = "About"

    /// Every title an entry's `section` may use.
    static let all: Set<String> = [
        app, library, libraryManagement, coreOptions, saves, audio, video, recording, retroAchievements,
        controller, hapticsRumble, dualSense, onScreenControls, analogDeadzone, deltaSkins,
        socialLinks, documentation, roadmap, build, extraInfo, advanced
    ]
}

extension SettingsTab {
    /// Display name shown in search breadcrumbs; matches the tab bar labels.
    var title: String {
        switch self {
        case .general: return "General"
        case .emulation: return "Emulation"
        case .controller: return "Controller"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }
}

// MARK: - Entries

struct SettingsSearchEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    /// Synonyms and related terms that are matched but never displayed.
    let keywords: [String]
    let tab: SettingsTab
    /// Exact `CollapsibleSection` title (see `SettingsSectionTitle`) that contains the row on iOS.
    let section: String
    /// `false` for rows that only exist in the iOS layout (or are compiled out on tvOS).
    let isAvailableOnTVOS: Bool
    /// `false` for rows that only exist on tvOS.
    let isAvailableOnIOS: Bool
    /// `true` for rows the app hides in App Store builds (sideload-only features).
    let hiddenInAppStore: Bool

    /// Whether the row is actually shown on this platform and build, so search never lands on a missing row.
    func isVisible(isAppStore: Bool) -> Bool {
        #if os(tvOS)
        let onThisPlatform = isAvailableOnTVOS
        #else
        let onThisPlatform = isAvailableOnIOS
        #endif
        return onThisPlatform && !(isAppStore && hiddenInAppStore)
    }

    /// Title of the `TVOSSettingsSection` that contains the row; tvOS folds several iOS sections together.
    var tvOSSection: String {
        switch section {
        case SettingsSectionTitle.hapticsRumble, SettingsSectionTitle.dualSense, SettingsSectionTitle.analogDeadzone:
            return SettingsSectionTitle.controller
        case SettingsSectionTitle.extraInfo:
            return SettingsSectionTitle.tvOSAbout
        default:
            return section
        }
    }
}

// MARK: - Search

enum SettingsSearchIndex {
    /// Queries shorter than this (after trimming) return no results.
    static let minimumQueryLength = 2

    /// Precomputed, folded text for matching so a keystroke does not re-normalise ~100 entries.
    private struct Searchable {
        let entry: SettingsSearchEntry
        let title: String
        let haystack: String
    }

    private static let searchables: [Searchable] = entries.map { entry in
        let haystack = ([entry.title, entry.subtitle ?? ""] + entry.keywords + [entry.section])
            .map { normalize($0) }
            .joined(separator: " ")
        return Searchable(entry: entry, title: normalize(entry.title), haystack: haystack)
    }

    private struct Ranked {
        let rank: Int
        let offset: Int
        let entry: SettingsSearchEntry
    }

    /// Case- and diacritic-insensitive folding.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Entries matching every whitespace-separated token of `query` somewhere in title, subtitle, keywords or
    /// section. Ordered: title starts with the query, then title contains it (or all tokens), then the rest;
    /// index order is kept within each group.
    static func search(_ query: String) -> [SettingsSearchEntry] {
        let normalizedQuery = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= minimumQueryLength else { return [] }
        let tokens = normalizedQuery.split(whereSeparator: \.isWhitespace).map(String.init)

        var ranked: [Ranked] = []
        for (offset, searchable) in searchables.enumerated() {
            guard tokens.allSatisfy({ searchable.haystack.contains($0) }) else { continue }
            let rank: Int
            if searchable.title.hasPrefix(normalizedQuery) {
                rank = 0
            } else if searchable.title.contains(normalizedQuery) || tokens.allSatisfy({ searchable.title.contains($0) }) {
                rank = 1
            } else {
                rank = 2
            }
            ranked.append(Ranked(rank: rank, offset: offset, entry: searchable.entry))
        }
        return ranked
            .sorted { ($0.rank, $0.offset) < ($1.rank, $1.offset) }
            .map(\.entry)
    }
}

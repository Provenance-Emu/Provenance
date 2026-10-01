//
//  CoreOptionsListModel.swift
//  PVUI
//
//  Layout, search and value access behind `CoreOptionsDetailView`, kept apart
//  from the view so they can be tested without rendering anything.
//

import Foundation
import PVCoreBridge

// MARK: - Scope

/// Where option changes are written: this game only, or every game on the core.
public enum CoreOptionsScope {
    /// Shared by the pause menu's option cells and the options list, so the two
    /// never disagree about which scope a change lands in.
    public static let perGameDefaultsKey = "PauseTileMenu.coreOptionsPerGame"
}

// MARK: - Sections

/// One editable option as the list presents it.
struct CoreOptionListRow: Identifiable, Equatable {
    /// Unique within the list. Not the storage key: cores do declare the same
    /// title twice, and SwiftUI needs distinct, stable identities to keep
    /// focus and scroll position across updates.
    let id: String
    let option: CoreOption

    var title: String { option.display.title }
    var detail: String? { option.display.description }
}

/// A category of options.
struct CoreOptionListSection: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
    let rows: [CoreOptionListRow]
}

enum CoreOptionListLayout {
    /// Sections start collapsed once a core has at least this many options
    /// spread over several categories — a 100-row scroll is not an overview.
    static let collapseThreshold = 20
    static let minimumSectionsToCollapse = 3

    /// Flattens a core's option tree into titled sections.
    ///
    /// Options outside any group are gathered into a leading section titled
    /// `generalTitle`. Nested groups become their own sections titled
    /// "Parent › Child", since the list is one level deep.
    static func sections(from options: [CoreOption], generalTitle: String) -> [CoreOptionListSection] {
        var general: [CoreOption] = []
        var groups: [(title: String, detail: String?, options: [CoreOption])] = []

        func collect(group display: CoreOptionValueDisplay, titled title: String, _ subOptions: [CoreOption]) {
            var leaves: [CoreOption] = []
            var nested: [(CoreOptionValueDisplay, [CoreOption])] = []
            for option in subOptions {
                if case let .group(childDisplay, childOptions) = option {
                    nested.append((childDisplay, childOptions))
                } else {
                    leaves.append(option)
                }
            }
            if !leaves.isEmpty {
                groups.append((title: title, detail: display.description, options: leaves))
            }
            for (childDisplay, childOptions) in nested {
                collect(group: childDisplay, titled: "\(title) › \(childDisplay.title)", childOptions)
            }
        }

        for option in options {
            if case let .group(display, subOptions) = option {
                collect(group: display, titled: display.title, subOptions)
            } else {
                general.append(option)
            }
        }
        if !general.isEmpty {
            groups.insert((title: generalTitle, detail: nil, options: general), at: 0)
        }

        /// An option listed both at the root and inside a group is one setting;
        /// showing it twice would give it two rows that fight over one value.
        var seenKeys = Set<String>()
        var sections: [CoreOptionListSection] = []
        for (index, group) in groups.enumerated() {
            let sectionID = "section.\(index)"
            let rows = group.options.compactMap { option -> CoreOptionListRow? in
                guard seenKeys.insert(option.key).inserted else { return nil }
                return CoreOptionListRow(id: "\(sectionID)/\(option.key)", option: option)
            }
            guard !rows.isEmpty else { continue }
            sections.append(CoreOptionListSection(id: sectionID, title: group.title, detail: group.detail, rows: rows))
        }
        return sections
    }

    /// Sections reduced to the rows matching every word of `query`.
    ///
    /// A word may match the option's title, its description, any of its
    /// choices, or the section title — so "audio" finds the whole Audio
    /// category and "2x" finds the resolution option that offers it.
    static func filter(_ sections: [CoreOptionListSection], matching query: String) -> [CoreOptionListSection] {
        let tokens = query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !tokens.isEmpty else { return sections }

        return sections.compactMap { section in
            let sectionText = searchable(section.title)
            let rows = section.rows.filter { row in
                let haystack = sectionText + " " + searchable(row.title) + " " + searchable(row.detail ?? "")
                    + " " + searchable(choiceTitles(of: row.option).joined(separator: " "))
                return tokens.allSatisfy { haystack.contains($0) }
            }
            guard !rows.isEmpty else { return nil }
            return CoreOptionListSection(id: section.id, title: section.title, detail: section.detail, rows: rows)
        }
    }

    /// IDs of the sections that should start collapsed.
    static func initiallyCollapsedSectionIDs(for sections: [CoreOptionListSection]) -> Set<String> {
        let optionCount = sections.reduce(0) { $0 + $1.rows.count }
        guard sections.count >= minimumSectionsToCollapse, optionCount >= collapseThreshold else { return [] }
        return Set(sections.dropFirst().map(\.id))
    }

    private static func searchable(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func choiceTitles(of option: CoreOption) -> [String] {
        switch option {
        case let .enumeration(_, values, _, _): return values.map(\.title)
        case let .multi(_, values, _): return values.map(\.title)
        default: return []
        }
    }
}

// MARK: - Values

/// Reads and writes option values for one core in one scope.
///
/// Values are read straight from what the user saved, falling back to the
/// option's own default, rather than through `storedValueForOption` — whose
/// miss path rebuilds the core's whole option list for every lookup.
struct CoreOptionValueStore {
    /// Step used when nudging a float range from a controller.
    static let floatStep: Float = 0.1

    let coreClass: CoreOptional.Type
    /// Game the values are scoped to, or `nil` for the core-wide values.
    let md5: String?

    // MARK: Reading

    private func stored(_ option: CoreOption) -> Any? {
        coreClass.explicitlyStoredValue(forOptionKey: option.key, md5: md5)
    }

    func bool(_ option: CoreOption) -> Bool {
        if let value = stored(option) as? Bool { return value }
        if case let .bool(_, defaultValue, _) = option { return defaultValue }
        return false
    }

    func int(_ option: CoreOption) -> Int {
        if let value = stored(option) as? Int { return value }
        switch option {
        case let .enumeration(_, _, defaultValue, _): return defaultValue
        case let .range(_, _, defaultValue, _): return defaultValue
        default: return 0
        }
    }

    func float(_ option: CoreOption) -> Float {
        if let value = stored(option) as? Float { return value }
        if let value = stored(option) as? Double { return Float(value) }
        if case let .rangef(_, _, defaultValue, _) = option { return defaultValue }
        return 0
    }

    func string(_ option: CoreOption) -> String {
        if let value = stored(option) as? String { return value }
        if case let .string(_, defaultValue, _) = option { return defaultValue }
        return ""
    }

    /// Index of the selected choice of a `.multi` option.
    ///
    /// Selections are saved by title; older builds saved the index, and a reset
    /// can leave the choice's description behind, so all three are accepted.
    func multiIndex(_ option: CoreOption) -> Int {
        guard case let .multi(_, values, _) = option, !values.isEmpty else { return 0 }
        let fallback = values.firstIndex(where: \.isDefault) ?? 0
        switch stored(option) {
        case let title as String:
            return values.firstIndex { $0.title == title }
                ?? values.firstIndex { $0.description == title }
                ?? fallback
        case let index as Int where values.indices.contains(index):
            return index
        default:
            return fallback
        }
    }

    /// The current value as shown at the trailing edge of a row.
    func displayValue(_ option: CoreOption) -> String {
        switch option {
        case .bool:
            return bool(option) ? String(localized: "On") : String(localized: "Off")
        case let .enumeration(_, values, _, _):
            let current = int(option)
            return values.first { $0.value == current }?.title ?? "\(current)"
        case .range:
            return "\(int(option))"
        case .rangef:
            return String(format: "%.1f", float(option))
        case let .multi(_, values, _):
            return values.isEmpty ? "" : values[multiIndex(option)].title
        case .string:
            return string(option)
        case .group:
            return ""
        }
    }

    /// Whether the user has changed this option in the current scope's view of
    /// it — i.e. a reset would do something.
    func isModified(_ option: CoreOption) -> Bool {
        stored(option) != nil
    }

    /// Whether this game overrides the core-wide value.
    func hasGameOverride(_ option: CoreOption) -> Bool {
        guard let md5 else { return false }
        return coreClass.hasPerGameOverride(for: option, md5: md5)
    }

    // MARK: Writing

    func set(_ value: Bool, for option: CoreOption) { coreClass.setValue(value, forOption: option, andMD5: md5) }
    func set(_ value: Int, for option: CoreOption) { coreClass.setValue(value, forOption: option, andMD5: md5) }
    func set(_ value: Float, for option: CoreOption) { coreClass.setValue(value, forOption: option, andMD5: md5) }
    func set(_ value: String, for option: CoreOption) { coreClass.setValue(value, forOption: option, andMD5: md5) }

    /// Selects a `.multi` choice by position.
    func setMulti(index: Int, for option: CoreOption) {
        guard case let .multi(_, values, _) = option, values.indices.contains(index) else { return }
        set(values[index].title, for: option)
    }

    /// Primary action on a row: flip a switch, or advance a choice (wrapping).
    func activate(_ option: CoreOption) {
        switch option {
        case .bool:
            set(!bool(option), for: option)
        case .enumeration, .multi:
            step(option, by: 1, wrapping: true)
        default:
            break
        }
    }

    /// Moves a value one step down (`direction < 0`) or up, stopping at the ends.
    func adjust(_ option: CoreOption, direction: Int) {
        guard direction != 0 else { return }
        let delta = direction > 0 ? 1 : -1
        switch option {
        case .bool:
            set(delta > 0, for: option)
        case .enumeration, .multi:
            step(option, by: delta, wrapping: false)
        case let .range(_, range, _, _):
            set(min(range.max, max(range.min, int(option) + delta)), for: option)
        case let .rangef(_, range, _, _):
            set(min(range.max, max(range.min, float(option) + Float(delta) * Self.floatStep)), for: option)
        default:
            break
        }
    }

    private func step(_ option: CoreOption, by delta: Int, wrapping: Bool) {
        func next(from current: Int, count: Int) -> Int {
            let target = current + delta
            return wrapping ? ((target % count) + count) % count : min(count - 1, max(0, target))
        }
        switch option {
        case let .enumeration(_, values, _, _):
            guard !values.isEmpty else { return }
            let currentValue = int(option)
            let current = values.firstIndex { $0.value == currentValue } ?? 0
            set(values[next(from: current, count: values.count)].value, for: option)
        case let .multi(_, values, _):
            guard !values.isEmpty else { return }
            setMulti(index: next(from: multiIndex(option), count: values.count), for: option)
        default:
            break
        }
    }

    /// Returns the option to what it would be had the user never touched it in
    /// this scope, and tells the running core.
    ///
    /// Forgetting a saved value changes nothing in the core by itself — it was
    /// applied when it was set — so the value now in effect is pushed through
    /// the option's handler explicitly.
    func reset(_ option: CoreOption) {
        coreClass.removeStoredValue(for: option, md5: md5)
        guard let handler = option.valueHandler else { return }
        let inherited = CoreOptionValueStore(coreClass: coreClass, md5: nil)
        switch option {
        case .bool: handler(inherited.bool(option))
        case .enumeration, .range: handler(inherited.int(option))
        case .rangef: handler(inherited.float(option))
        case .multi: handler(inherited.displayValue(option))
        case .string: handler(inherited.string(option))
        case .group: break
        }
    }
}

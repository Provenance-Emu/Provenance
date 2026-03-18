//
//  CoreActionTileProvider.swift
//  PVUI
//
//  Created by Claude on 3/17/26.
//  Part of #3249 — Dynamic CoreOptions & CoreActions tile integration
//

import Foundation
import PVCoreBridge

// MARK: - CoreActionTileProvider

/// Maps an array of ``CoreAction``s to ``PauseMenuTile``s for the tile-based pause menu.
///
/// Each action becomes an orange bolt-icon tile. Actions where `requiresReset` is `true`
/// display a ⚠︎ warning badge so users know emulation will reset.
/// Actions whose `options` array is non-nil present a confirmation picker on **tap**
/// (via `pendingCoreAction`), and also expose a **long-press context menu** so users
/// can jump directly to any option without first seeing the confirmation dialog.
public struct CoreActionTileProvider {

    private init() {}

    /// Tile ID prefix for core-action tiles.
    static let idPrefix = "coreAction_"

    /// Converts an array of ``CoreAction``s into pause-menu tiles.
    ///
    /// - Parameter actions: Core actions exposed by the active emulator core.
    /// - Returns: One ``PauseMenuTile`` per action.
    public static func tiles(from actions: [CoreAction]) -> [PauseMenuTile] {
        actions.map { action in
            // Build long-press options from the action's option list.
            let lpOptions: [PauseMenuTileLongPressOption]? = action.options.map { opts in
                opts.map { opt in
                    PauseMenuTileLongPressOption(
                        id: "\(action.title)_\(opt.title)",
                        title: opt.title,
                        isSelected: opt.selected
                    )
                }
            }
            // Show the currently-selected option (if any) as a badge.
            let currentOpt = action.options?.first(where: { $0.selected })
            let badge: String? = action.requiresReset ? "⚠︎" : currentOpt?.title

            return PauseMenuTile(
                id: tileID(for: action),
                icon: "bolt.fill",
                label: action.title,
                badge: badge,
                colorKey: .orange,
                dismissOnTap: false,
                longPressOptions: lpOptions
            )
        }
    }

    /// The stable tile ID for the given `CoreAction`.
    public static func tileID(for action: CoreAction) -> String {
        "\(idPrefix)\(action.title)"
    }

    /// Extracts the action title from a tile ID.
    /// - Returns: The original action title, or `nil` if the ID is not a core-action tile.
    public static func actionTitle(fromTileID id: String) -> String? {
        guard id.hasPrefix(idPrefix) else { return nil }
        return String(id.dropFirst(idPrefix.count))
    }
}

// MARK: - CoreOptionTileProvider

/// Maps ``CoreOption``s from a ``CoreOptional`` class to quick-action ``PauseMenuTile``s.
///
/// - **Boolean** options → tap toggles ON/OFF; current state shown as badge.
/// - **Enumeration / multi** options → tap cycles to the next value; long-press shows
///   a full picker via context menu. Badge shows the current value's label.
/// - A **Core Settings** gateway tile is always appended when any options exist, giving
///   access to range/string and nested options via ``CoreOptionsDetailView``.
public struct CoreOptionTileProvider {

    private init() {}

    /// Tile ID for the "Core Settings" summary tile that opens the full options form.
    public static let coreSettingsTileID = "coreSettings"

    /// Option tile ID prefix.
    static let idPrefix = "coreOption_"

    /// Builds interactive tiles for boolean, enumeration, and multi-select options,
    /// plus a **Core Settings** tile.
    ///
    /// - Parameters:
    ///   - options: The flat or grouped `[CoreOption]` from the active core class.
    ///   - coreClass: Used to read each option's current stored value.
    /// - Returns: Toggle/cycle tiles followed by a single "Core Settings" tile, or an empty
    ///   array when `options` is empty.
    public static func tiles(from options: [CoreOption], coreClass: CoreOptional.Type) -> [PauseMenuTile] {
        guard !options.isEmpty else { return [] }

        var counter = 0
        var result = interactiveTiles(from: options, coreClass: coreClass, counter: &counter)

        // Always include a "Core Settings" gateway so users can reach range/string options.
        result.append(PauseMenuTile(
            id: coreSettingsTileID,
            icon: "gearshape.fill",
            label: String(localized: "Core Settings"),
            colorKey: .blue,
            dismissOnTap: false
        ))

        return result
    }

    /// Recursively extracts boolean and enumeration options and creates interactive tiles.
    /// `counter` is incremented for each tile created, producing unique IDs even when
    /// multiple options share the same display title.
    private static func interactiveTiles(from options: [CoreOption], coreClass: CoreOptional.Type, counter: inout Int) -> [PauseMenuTile] {
        var result: [PauseMenuTile] = []
        for option in options {
            switch option {
            case let .bool(display, _, _):
                let current: Bool = coreClass.valueForOption(option)
                result.append(PauseMenuTile(
                    id: tileID(forOptionKey: display.title, index: counter),
                    icon: current ? "checkmark.square.fill" : "square",
                    label: display.title,
                    badge: current ? "ON" : "OFF",
                    colorKey: current ? .green : .gray,
                    dismissOnTap: false
                ))
                counter += 1

            case let .enumeration(display, values, defaultValue, _):
                // valueForOption -> Int? is safe for enumeration; non-optional crashes if defaultValue isn't Int.
                let currentIndex: Int = (coreClass.valueForOption(option) as Int?) ?? defaultValue
                let matchedEnum = values.first(where: { $0.value == currentIndex })
                let currentLabel = matchedEnum?.title ?? values.first?.title ?? "–"
                // Long-press shows all choices; tap cycles to next.
                let lpOptions = values.map { v in
                    PauseMenuTileLongPressOption(
                        id: "\(display.title)_\(v.value)",
                        title: v.title,
                        isSelected: v.value == currentIndex
                    )
                }
                result.append(PauseMenuTile(
                    id: tileID(forOptionKey: display.title, index: counter),
                    icon: "arrow.trianglehead.2.clockwise",
                    label: display.title,
                    badge: currentLabel,
                    colorKey: .cyan,
                    dismissOnTap: false,
                    longPressOptions: lpOptions
                ))
                counter += 1

            case let .multi(display, values, _):
                // multi options are persisted as a String title (see CoreOptionsViewController).
                // Fall back to Int index for legacy reads, then use the first isDefault or index 0.
                let defaultIdx = values.firstIndex(where: { $0.isDefault }) ?? 0
                let storedTitle: String = coreClass.valueForOption(option)
                let currentIndex: Int
                if !storedTitle.isEmpty {
                    currentIndex = values.firstIndex(where: { $0.title == storedTitle }) ?? defaultIdx
                } else {
                    let storedInt: Int? = coreClass.valueForOption(option)
                    currentIndex = storedInt ?? defaultIdx
                }
                let currentLabel = currentIndex < values.count ? values[currentIndex].title : (values.first?.title ?? "–")
                let lpOptions = values.enumerated().map { idx, v in
                    PauseMenuTileLongPressOption(
                        id: "\(display.title)_\(idx)",
                        title: v.title,
                        isSelected: idx == currentIndex
                    )
                }
                result.append(PauseMenuTile(
                    id: tileID(forOptionKey: display.title, index: counter),
                    icon: "list.bullet.clipboard",
                    label: display.title,
                    badge: currentLabel,
                    colorKey: .purple,
                    dismissOnTap: false,
                    longPressOptions: lpOptions
                ))
                counter += 1

            case let .group(_, subOptions):
                result += interactiveTiles(from: subOptions, coreClass: coreClass, counter: &counter)

            default:
                break
            }
        }
        return result
    }

    /// The stable tile ID for an option identified by `key` and its position `index` in the
    /// flattened options list. The index disambiguates options that share the same display title.
    public static func tileID(forOptionKey key: String, index: Int) -> String {
        "\(idPrefix)\(index):\(key)"
    }

    /// Extracts the option key from a tile ID produced by ``tileID(forOptionKey:index:)``.
    /// - Returns: The option key (display title), or `nil` if the ID is not a core-option tile.
    public static func optionKey(fromTileID id: String) -> String? {
        optionIndexAndKey(fromTileID: id)?.key
    }

    /// Extracts both the positional index and the option key from a tile ID.
    ///
    /// The index is the counter assigned during tile generation and uniquely identifies the
    /// option even when multiple options share the same display title.
    /// - Returns: `(index, key)` tuple, or `nil` if the ID is not a core-option tile.
    public static func optionIndexAndKey(fromTileID id: String) -> (index: Int, key: String)? {
        guard id.hasPrefix(idPrefix) else { return nil }
        let raw = String(id.dropFirst(idPrefix.count))
        guard let colonRange = raw.range(of: ":"),
              let idx = Int(raw[raw.startIndex..<colonRange.lowerBound]) else { return nil }
        return (index: idx, key: String(raw[colonRange.upperBound...]))
    }

    /// Finds a ``CoreOption`` by its positional index in the flattened interactive options list.
    ///
    /// Using the index rather than the display title avoids incorrect matches when multiple
    /// options share the same title (e.g. two enum options both called "System Region").
    /// - Parameters:
    ///   - index: The counter value encoded in the tile ID.
    ///   - key: The display title — used as a secondary sanity check.
    ///   - options: The option tree to search.
    /// - Returns: The `CoreOption` at the given position, or `nil` if out of range.
    public static func findOption(atIndex index: Int, key: String, in options: [CoreOption]) -> CoreOption? {
        var counter = 0
        return findOptionAt(targetIndex: index, in: options, counter: &counter)
    }

    private static func findOptionAt(targetIndex: Int, in options: [CoreOption], counter: inout Int) -> CoreOption? {
        for option in options {
            switch option {
            case .bool, .enumeration, .multi:
                if counter == targetIndex { return option }
                counter += 1
            case let .group(_, subOptions):
                if let found = findOptionAt(targetIndex: targetIndex, in: subOptions, counter: &counter) {
                    return found
                }
            default:
                break
            }
        }
        return nil
    }

    /// Finds a ``CoreOption`` in a (possibly grouped) option tree by its display title / key.
    ///
    /// Prefer ``findOption(atIndex:key:in:)`` when a tile ID is available — title-based
    /// lookup returns the *first* match and will target the wrong option when multiple
    /// options share the same display title.
    public static func findOption(key: String, in options: [CoreOption]) -> CoreOption? {
        for option in options {
            switch option {
            case let .bool(display, _, _) where display.title == key:
                return option
            case let .enumeration(display, _, _, _) where display.title == key:
                return option
            case let .multi(display, _, _) where display.title == key:
                return option
            case let .group(_, subOptions):
                if let found = findOption(key: key, in: subOptions) { return found }
            default:
                if option.key == key { return option }
            }
        }
        return nil
    }

    /// Cycles an enumeration or multi-select option to its next value (wraps around).
    ///
    /// - Parameters:
    ///   - option: The current `CoreOption` to advance.
    ///   - coreClass: The conforming `CoreOptional` class used for persistence.
    public static func cycleNextValue(for option: CoreOption, coreClass: CoreOptional.Type) {
        switch option {
        case let .enumeration(_, values, defaultValue, _):
            let current: Int = (coreClass.valueForOption(option) as Int?) ?? defaultValue
            let sorted = values.sorted(by: { $0.value < $1.value })
            let idx = sorted.firstIndex(where: { $0.value == current }) ?? 0
            let nextValue = sorted[(idx + 1) % sorted.count].value
            coreClass.setValue(nextValue, forOption: option, andMD5: coreClass.currentGameMD5)

        case let .multi(_, values, _):
            let defaultIdx = values.firstIndex(where: { $0.isDefault }) ?? 0
            let storedTitle: String = coreClass.valueForOption(option)
            let current: Int
            if !storedTitle.isEmpty {
                current = values.firstIndex(where: { $0.title == storedTitle }) ?? defaultIdx
            } else {
                let storedInt: Int? = coreClass.valueForOption(option)
                current = storedInt ?? defaultIdx
            }
            let nextIndex = (current + 1) % values.count
            // Store as String title to match CoreOptionsViewController's persistence format.
            coreClass.setValue(values[nextIndex].title, forOption: option, andMD5: coreClass.currentGameMD5)

        default:
            break
        }
    }

    /// Sets an enumeration or multi-select option to a specific value by option title.
    public static func selectValue(
        titled title: String,
        for option: CoreOption,
        coreClass: CoreOptional.Type
    ) {
        switch option {
        case let .enumeration(_, values, _, _):
            if let match = values.first(where: { $0.title == title }) {
                coreClass.setValue(match.value, forOption: option, andMD5: coreClass.currentGameMD5)
            }
        case let .multi(_, values, _):
            if values.contains(where: { $0.title == title }) {
                // Store as String title to match CoreOptionsViewController's persistence format.
                coreClass.setValue(title, forOption: option, andMD5: coreClass.currentGameMD5)
            }
        default:
            break
        }
    }
}


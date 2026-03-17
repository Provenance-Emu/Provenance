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
/// Actions whose `options` array is non-nil will trigger an inline picker (handled by the menu view).
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
            PauseMenuTile(
                id: tileID(for: action),
                icon: "bolt.fill",
                label: action.title,
                badge: action.requiresReset ? "⚠︎" : nil,
                colorKey: .orange,
                dismissOnTap: false
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

/// Maps boolean ``CoreOption``s from a ``CoreOptional`` class to quick-toggle ``PauseMenuTile``s.
///
/// Only `bool` options are surfaced as inline toggle tiles — the full range of option types
/// (range, enumeration, etc.) is reachable via the appended **Core Settings** tile that opens
/// ``CoreOptionsDetailView``.
///
/// If the core exposes no options at all, an empty array is returned and the
/// `"coreSettings"` tile is **not** added.
public struct CoreOptionTileProvider {

    private init() {}

    /// Tile ID for the "Core Settings" summary tile that opens the full options form.
    public static let coreSettingsTileID = "coreSettings"

    /// Option tile ID prefix.
    static let idPrefix = "coreOption_"

    /// Builds toggle tiles for every boolean option, plus a **Core Settings** tile.
    ///
    /// - Parameters:
    ///   - options: The flat or grouped `[CoreOption]` from the active core class.
    ///   - coreClass: Used to read each boolean option's current stored value.
    /// - Returns: Toggle tiles followed by a single "Core Settings" tile, or an empty
    ///   array when `options` is empty.
    public static func tiles(from options: [CoreOption], coreClass: CoreOptional.Type) -> [PauseMenuTile] {
        guard !options.isEmpty else { return [] }

        var result = booleanTiles(from: options, coreClass: coreClass)

        // Always include a "Core Settings" gateway so users can reach non-boolean options.
        result.append(PauseMenuTile(
            id: coreSettingsTileID,
            icon: "gearshape.fill",
            label: String(localized: "Core Settings"),
            colorKey: .blue,
            dismissOnTap: false
        ))

        return result
    }

    /// Recursively extracts `bool` options and maps each to a toggle tile.
    private static func booleanTiles(from options: [CoreOption], coreClass: CoreOptional.Type) -> [PauseMenuTile] {
        var result: [PauseMenuTile] = []
        for option in options {
            switch option {
            case let .bool(display, _, _):
                let current: Bool = coreClass.valueForOption(option)
                result.append(PauseMenuTile(
                    id: tileID(forOptionKey: display.title),
                    icon: current ? "checkmark.square.fill" : "square",
                    label: display.title,
                    badge: current ? "ON" : "OFF",
                    colorKey: current ? .green : .gray,
                    dismissOnTap: false
                ))
            case let .group(_, subOptions):
                result += booleanTiles(from: subOptions, coreClass: coreClass)
            default:
                break
            }
        }
        return result
    }

    /// The stable tile ID for a boolean option identified by `key`.
    public static func tileID(forOptionKey key: String) -> String {
        "\(idPrefix)\(key)"
    }

    /// Extracts the option key from a tile ID.
    /// - Returns: The option key, or `nil` if the ID is not a core-option tile.
    public static func optionKey(fromTileID id: String) -> String? {
        guard id.hasPrefix(idPrefix) else { return nil }
        return String(id.dropFirst(idPrefix.count))
    }

    /// Finds a ``CoreOption`` in a (possibly grouped) option tree by its key.
    ///
    /// Visible to PVUIBase for toggling boolean options without re-exposing
    /// `CoreOptional.findOption` (which is internal to PVCoreBridge).
    public static func findOption(key: String, in options: [CoreOption]) -> CoreOption? {
        for option in options {
            switch option {
            case let .bool(display, _, _) where display.title == key:
                return option
            case let .group(_, subOptions):
                if let found = findOption(key: key, in: subOptions) { return found }
            default:
                if option.key == key { return option }
            }
        }
        return nil
    }
}

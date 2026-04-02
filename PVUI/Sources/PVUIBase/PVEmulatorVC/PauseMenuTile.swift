//
//  PauseMenuTile.swift
//  PVUI
//
//  Created by Claude on 3/17/26.
//  Part of #3248 — tile-based pause menu (feature-flagged)
//

import Foundation

// MARK: - Tile Data Model

/// Route identifiers for nested tile-menu navigation.
public enum PauseTileMenuRoute: String, Sendable, Hashable, CaseIterable {
    case root
    case states
    case options
    case recording
    /// Controller profiles, port devices, touch keyboard/mouse, rumble, and related input tiles.
    case controls
    case core
    /// Skins submenu in `PauseTileMenuView`. Choosing a portrait/landscape skin presents `SystemSkinSelectionView` (same sheet as the library), not this file.
    case skins
}

/// A single action tile in the tile-based pause menu grid.
public struct PauseMenuTile: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    /// SF Symbol name for the tile icon.
    public let icon: String
    /// Short label displayed below the icon.
    public let label: String
    /// Optional badge text (e.g. save slot number, recording indicator, current value).
    public var badge: String?
    /// Help text from the core option's `CoreOptionValueDisplay.description`.
    /// Shown in the info shelf when the tile is focused/long-pressed.
    public var description: String?
    /// Whether the tile is interactive; disabled tiles are dimmed.
    public var isEnabled: Bool
    /// Accent color key — maps to the retrowave palette.
    public let colorKey: PauseMenuTileColor
    /// Whether tapping this tile should close the overlay first (vs. immediate inline action).
    public let dismissOnTap: Bool
    /// Optional list of choices for long-press context menu (e.g. enum option values).
    public var longPressOptions: [PauseMenuTileLongPressOption]?
    /// Optional nested destination route. Non-nil means this tile opens a submenu.
    public let destinationRoute: PauseTileMenuRoute?

    public init(
        id: String,
        icon: String,
        label: String,
        badge: String? = nil,
        description: String? = nil,
        isEnabled: Bool = true,
        colorKey: PauseMenuTileColor = .blue,
        dismissOnTap: Bool = true,
        longPressOptions: [PauseMenuTileLongPressOption]? = nil,
        destinationRoute: PauseTileMenuRoute? = nil
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.badge = badge
        self.description = description
        self.isEnabled = isEnabled
        self.colorKey = colorKey
        self.dismissOnTap = dismissOnTap
        self.longPressOptions = longPressOptions
        self.destinationRoute = destinationRoute
    }
}

// MARK: - Long-Press Option

/// A named option surfaced by a long-press context menu on a tile.
public struct PauseMenuTileLongPressOption: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Whether this option is the currently-active value.
    public let isSelected: Bool

    public init(id: String, title: String, isSelected: Bool = false) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
    }
}

// MARK: - Tile Color Keys

/// Semantic color keys for tile accents, matching the retrowave palette.
public enum PauseMenuTileColor: String, Sendable {
    case green, orange, blue, purple, pink, cyan, yellow, gray, teal, red
}

// MARK: - Tile Section

/// A named group of tiles displayed together in the grid.
public struct PauseMenuTileSection: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    /// Human-readable section header (nil = no visible header).
    public let title: String?
    public let tiles: [PauseMenuTile]

    public init(id: String, title: String? = nil, tiles: [PauseMenuTile]) {
        self.id = id
        self.title = title
        self.tiles = tiles
    }
}

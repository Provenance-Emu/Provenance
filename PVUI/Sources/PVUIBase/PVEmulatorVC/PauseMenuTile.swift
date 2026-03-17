//
//  PauseMenuTile.swift
//  PVUI
//
//  Created by Claude on 3/17/26.
//  Part of #3248 — tile-based pause menu (feature-flagged)
//

import Foundation

// MARK: - Tile Data Model

/// A single action tile in the tile-based pause menu grid.
public struct PauseMenuTile: Identifiable, Sendable {
    public let id: String
    /// SF Symbol name for the tile icon.
    public let icon: String
    /// Short label displayed below the icon.
    public let label: String
    /// Optional badge text (e.g. save slot number, recording indicator).
    public var badge: String?
    /// Whether the tile is interactive; disabled tiles are dimmed.
    public var isEnabled: Bool
    /// Accent color key — maps to the retrowave palette.
    public let colorKey: PauseMenuTileColor
    /// Whether tapping this tile should close the overlay first (vs. immediate inline action).
    public let dismissOnTap: Bool

    public init(
        id: String,
        icon: String,
        label: String,
        badge: String? = nil,
        isEnabled: Bool = true,
        colorKey: PauseMenuTileColor = .blue,
        dismissOnTap: Bool = true
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.badge = badge
        self.isEnabled = isEnabled
        self.colorKey = colorKey
        self.dismissOnTap = dismissOnTap
    }
}

// MARK: - Tile Color Keys

/// Semantic color keys for tile accents, matching the retrowave palette.
public enum PauseMenuTileColor: String, Sendable {
    case green, orange, blue, purple, pink, cyan, yellow, gray
}

// MARK: - Tile Section

/// A named group of tiles displayed together in the grid.
public struct PauseMenuTileSection: Identifiable, Sendable {
    public let id: String
    public let tiles: [PauseMenuTile]

    public init(id: String, tiles: [PauseMenuTile]) {
        self.id = id
        self.tiles = tiles
    }
}

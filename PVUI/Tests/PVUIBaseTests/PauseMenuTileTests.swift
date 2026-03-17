//
//  PauseMenuTileTests.swift
//  PVUIBaseTests
//
//  Tests for PauseMenuTile and PauseMenuTileSection data models.
//

import Testing
@testable import PVUIBase

@Suite("PauseMenuTile Tests")
struct PauseMenuTileTests {

    @Test("Tile ID is stable and preserved")
    func tileIDIsStable() {
        let tile = PauseMenuTile(id: "resume", icon: "play.fill", label: "Resume")
        #expect(tile.id == "resume")
    }

    @Test("Default values are sensible")
    func tileDefaultValues() {
        let tile = PauseMenuTile(id: "test", icon: "star", label: "Test")
        #expect(tile.badge == nil)
        #expect(tile.isEnabled == true)
        #expect(tile.colorKey == .blue)
        #expect(tile.dismissOnTap == true)
    }

    @Test("Badge can be set")
    func tileBadgeSet() {
        let tile = PauseMenuTile(id: "saves", icon: "square", label: "Saves", badge: "3")
        #expect(tile.badge == "3")
    }

    @Test("Disabled tile has isEnabled false")
    func tileDisabled() {
        let tile = PauseMenuTile(id: "cheats", icon: "wand", label: "Cheats", isEnabled: false)
        #expect(tile.isEnabled == false)
    }

    @Test("Tiles with same ID are equal via Identifiable")
    func tileIdentifiableUniqueness() {
        let tileA = PauseMenuTile(id: "resume", icon: "play.fill", label: "Resume")
        let tileB = PauseMenuTile(id: "quit", icon: "xmark", label: "Quit")
        #expect(tileA.id != tileB.id)
    }

    @Test("All color keys have distinct raw values")
    func colorKeyRawValues() {
        let keys: [PauseMenuTileColor] = [.green, .orange, .blue, .purple, .pink, .cyan, .yellow, .gray]
        let rawValues = keys.map(\.rawValue)
        let unique = Set(rawValues)
        #expect(unique.count == keys.count)
    }

    @Test("PauseMenuTileSection preserves tile order")
    func sectionPreservesTileOrder() {
        let tiles = [
            PauseMenuTile(id: "a", icon: "1.circle", label: "A"),
            PauseMenuTile(id: "b", icon: "2.circle", label: "B"),
            PauseMenuTile(id: "c", icon: "3.circle", label: "C"),
        ]
        let section = PauseMenuTileSection(id: "primary", tiles: tiles)
        #expect(section.tiles.map(\.id) == ["a", "b", "c"])
    }

    @Test("PauseMenuTileSection ID is preserved")
    func sectionIDPreserved() {
        let section = PauseMenuTileSection(id: "main", tiles: [])
        #expect(section.id == "main")
    }

    @Test("PauseMenuTile is Sendable")
    func tileSendable() {
        // Compile-time check: PauseMenuTile conforms to Sendable
        let _: any Sendable = PauseMenuTile(id: "test", icon: "star", label: "Test")
    }

    @Test("PauseMenuTileSection is Sendable")
    func sectionSendable() {
        let _: any Sendable = PauseMenuTileSection(id: "test", tiles: [])
    }
}

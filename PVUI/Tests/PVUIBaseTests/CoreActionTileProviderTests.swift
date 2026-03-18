//
//  CoreActionTileProviderTests.swift
//  PVUIBaseTests
//
//  Tests for CoreActionTileProvider and CoreOptionTileProvider.
//  Part of #3249 — Dynamic CoreOptions & CoreActions tile integration.
//

import Testing
import PVCoreBridge
@testable import PVUIBase

// MARK: - Mock Core

/// Minimal CoreOptional conforming type used in option provider tests.
private final class MockCore: CoreOptional {
    static var currentGameMD5: String? { nil }
    static let options: [CoreOption] = [
        .bool(
            CoreOptionValueDisplay(title: "Enable Feature", description: "Toggles the feature"),
            defaultValue: false
        ),
        .bool(
            CoreOptionValueDisplay(title: "Fast Mode", description: nil),
            defaultValue: true
        ),
        .range(
            CoreOptionValueDisplay(title: "Speed", description: nil),
            range: CoreOptionRange(defaultValue: 5, min: 0, max: 10),
            defaultValue: 5
        ),
        .group(
            CoreOptionValueDisplay(title: "Advanced", description: nil),
            subOptions: [
                .bool(
                    CoreOptionValueDisplay(title: "Debug Mode", description: nil),
                    defaultValue: false
                )
            ]
        )
    ]
}

/// Minimal CoreOptional conforming type with no options.
private final class EmptyCore: CoreOptional {
    static var currentGameMD5: String? { nil }
    static let options: [CoreOption] = []
}

// MARK: - CoreActionTileProvider Tests

@Suite("CoreActionTileProvider Tests")
struct CoreActionTileProviderTests {

    @Test("Maps CoreAction to tile with bolt icon")
    func actionMapsToTile() {
        let action = CoreAction(title: "Insert Disc 2", requiresReset: false)
        let tiles = CoreActionTileProvider.tiles(from: [action])
        #expect(tiles.count == 1)
        #expect(tiles[0].icon == "bolt.fill")
        #expect(tiles[0].label == "Insert Disc 2")
        #expect(tiles[0].colorKey == .orange)
    }

    @Test("requiresReset action shows warning badge")
    func resetRequiredShowsBadge() {
        let action = CoreAction(title: "Swap Memory Card", requiresReset: true)
        let tiles = CoreActionTileProvider.tiles(from: [action])
        #expect(tiles[0].badge == "⚠︎")
    }

    @Test("Normal action has no badge")
    func normalActionNoBadge() {
        let action = CoreAction(title: "Toggle Cheats", requiresReset: false)
        let tiles = CoreActionTileProvider.tiles(from: [action])
        #expect(tiles[0].badge == nil)
    }

    @Test("Empty actions array produces empty tiles")
    func emptyActionsProducesNoTiles() {
        let tiles = CoreActionTileProvider.tiles(from: [])
        #expect(tiles.isEmpty)
    }

    @Test("Multiple actions produce one tile each")
    func multipleActionsProduceMultipleTiles() {
        let actions = [
            CoreAction(title: "Action A"),
            CoreAction(title: "Action B"),
            CoreAction(title: "Action C")
        ]
        let tiles = CoreActionTileProvider.tiles(from: actions)
        #expect(tiles.count == 3)
    }

    @Test("Tile ID encodes action title")
    func tileIDEncodesTitle() {
        let action = CoreAction(title: "Insert Disc 2")
        let id = CoreActionTileProvider.tileID(for: action)
        #expect(id.hasPrefix(CoreActionTileProvider.idPrefix))
        #expect(id.contains("Insert Disc 2"))
    }

    @Test("actionTitle round-trips through tileID")
    func actionTitleRoundTrips() {
        let action = CoreAction(title: "My Action")
        let id = CoreActionTileProvider.tileID(for: action)
        let recovered = CoreActionTileProvider.actionTitle(fromTileID: id)
        #expect(recovered == "My Action")
    }

    @Test("actionTitle returns nil for non-action tile IDs")
    func actionTitleNilForOtherIDs() {
        #expect(CoreActionTileProvider.actionTitle(fromTileID: "resume") == nil)
        #expect(CoreActionTileProvider.actionTitle(fromTileID: "coreOption_Foo") == nil)
    }

    @Test("dismissOnTap is false (action tiles don't auto-dismiss)")
    func dismissOnTapIsFalse() {
        let action = CoreAction(title: "Do Something")
        let tiles = CoreActionTileProvider.tiles(from: [action])
        #expect(tiles[0].dismissOnTap == false)
    }

    @Test("Tile is enabled by default")
    func tileIsEnabled() {
        let action = CoreAction(title: "Enable JIT")
        let tiles = CoreActionTileProvider.tiles(from: [action])
        #expect(tiles[0].isEnabled == true)
    }
}

// MARK: - CoreOptionTileProvider Tests

@Suite("CoreOptionTileProvider Tests")
struct CoreOptionTileProviderTests {

    @Test("Empty options returns empty array (no coreSettings tile)")
    func emptyOptionsReturnsEmpty() {
        let tiles = CoreOptionTileProvider.tiles(from: [], coreClass: EmptyCore.self)
        #expect(tiles.isEmpty)
    }

    @Test("Bool options produce toggle tiles plus coreSettings tile")
    func boolOptionsProduceTilesAndSettings() {
        let tiles = CoreOptionTileProvider.tiles(from: MockCore.options, coreClass: MockCore.self)
        // 2 top-level booleans + 1 nested boolean in group + 1 coreSettings tile
        let boolTiles = tiles.filter { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) }
        let settingsTile = tiles.first(where: { $0.id == CoreOptionTileProvider.coreSettingsTileID })
        #expect(boolTiles.count == 3)
        #expect(settingsTile != nil)
    }

    @Test("Non-boolean options are not surfaced as toggle tiles")
    func rangeOptionNotSurfaced() {
        let tiles = CoreOptionTileProvider.tiles(from: MockCore.options, coreClass: MockCore.self)
        // The range option "Speed" should not appear as a tile
        let speedTile = tiles.first(where: { $0.label == "Speed" })
        #expect(speedTile == nil)
    }

    @Test("Core Settings tile has gearshape icon and blue color")
    func coreSettingsTileHasCorrectAppearance() {
        let tiles = CoreOptionTileProvider.tiles(from: MockCore.options, coreClass: MockCore.self)
        let settingsTile = tiles.first(where: { $0.id == CoreOptionTileProvider.coreSettingsTileID })
        #expect(settingsTile?.icon == "gearshape.fill")
        #expect(settingsTile?.colorKey == .blue)
    }

    @Test("Core Settings tile is always last")
    func coreSettingsTileIsLast() {
        let tiles = CoreOptionTileProvider.tiles(from: MockCore.options, coreClass: MockCore.self)
        #expect(tiles.last?.id == CoreOptionTileProvider.coreSettingsTileID)
    }

    @Test("tileID round-trips through optionKey")
    func tileIDRoundTrips() {
        let key = "Enable Feature"
        let id = CoreOptionTileProvider.tileID(forOptionKey: key, index: 3)
        let recovered = CoreOptionTileProvider.optionKey(fromTileID: id)
        #expect(recovered == key)
    }

    @Test("optionKey returns nil for non-option tile IDs")
    func optionKeyNilForOtherIDs() {
        #expect(CoreOptionTileProvider.optionKey(fromTileID: "resume") == nil)
        #expect(CoreOptionTileProvider.optionKey(fromTileID: "coreAction_Foo") == nil)
    }

    @Test("findOption locates top-level bool option by key")
    func findOptionTopLevel() {
        let found = CoreOptionTileProvider.findOption(key: "Enable Feature", in: MockCore.options)
        #expect(found != nil)
        if case .bool(let display, _, _) = found {
            #expect(display.title == "Enable Feature")
        }
    }

    @Test("findOption locates nested bool option inside group")
    func findOptionNested() {
        let found = CoreOptionTileProvider.findOption(key: "Debug Mode", in: MockCore.options)
        #expect(found != nil)
    }

    @Test("findOption returns nil for missing key")
    func findOptionNilForMissingKey() {
        let found = CoreOptionTileProvider.findOption(key: "NonExistent", in: MockCore.options)
        #expect(found == nil)
    }

    @Test("Grouped bool options are recursively extracted")
    func groupedOptionsAreExtracted() {
        let tiles = CoreOptionTileProvider.tiles(from: MockCore.options, coreClass: MockCore.self)
        // Find by label since tile IDs now include a positional index disambiguator.
        let debugTile = tiles.first(where: { $0.label == "Debug Mode" })
        #expect(debugTile != nil)
    }

    @Test("Toggle tile dismissOnTap is false")
    func toggleTileDismissOnTapIsFalse() {
        let options: [CoreOption] = [
            .bool(CoreOptionValueDisplay(title: "Flag"), defaultValue: false)
        ]
        let tiles = CoreOptionTileProvider.tiles(from: options, coreClass: MockCore.self)
        let boolTile = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })
        #expect(boolTile?.dismissOnTap == false)
    }
}

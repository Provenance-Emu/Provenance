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

/// Mock core with a single enumeration option.
private final class EnumCore: CoreOptional {
    static var currentGameMD5: String? { nil }
    static let options: [CoreOption] = [
        .enumeration(
            CoreOptionValueDisplay(title: "Color Depth", description: "Bit depth"),
            values: [
                CoreOptionEnumValue(title: "8-bit", description: "256 colors", value: 0),
                CoreOptionEnumValue(title: "16-bit", description: "65K colors", value: 1),
                CoreOptionEnumValue(title: "32-bit", description: "True color", value: 2)
            ],
            defaultValue: 0
        )
    ]
}

/// Mock core with a single multi-select option.
private final class MultiCore: CoreOptional {
    static var currentGameMD5: String? { nil }
    static let options: [CoreOption] = [
        .multi(
            CoreOptionValueDisplay(title: "System Region", description: "Console region"),
            values: [
                CoreOptionMultiValue(title: "Auto", description: "Detect automatically"),
                CoreOptionMultiValue(title: "NTSC", description: "NTSC region"),
                CoreOptionMultiValue(title: "PAL", description: "PAL region")
            ]
        )
    ]
}

/// Mock core with two enumeration options that share the same display title —
/// simulates real-world cores like PVAzaharCore that expose multiple "System Region"
/// enumerations for different sub-systems.
private final class DuplicateTitleCore: CoreOptional {
    static var currentGameMD5: String? { nil }
    static let options: [CoreOption] = [
        .enumeration(
            CoreOptionValueDisplay(title: "System Region", description: "Primary region"),
            values: [
                CoreOptionEnumValue(title: "Auto", description: nil, value: 0),
                CoreOptionEnumValue(title: "NTSC", description: nil, value: 1)
            ],
            defaultValue: 0
        ),
        .enumeration(
            CoreOptionValueDisplay(title: "System Region", description: "Secondary region"),
            values: [
                CoreOptionEnumValue(title: "EU", description: nil, value: 0),
                CoreOptionEnumValue(title: "JP", description: nil, value: 1)
            ],
            defaultValue: 0
        )
    ]
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

// MARK: - Enumeration Tile Tests

@Suite("CoreOptionTileProvider Enumeration Tile Tests")
struct CoreOptionTileProviderEnumTests {

    @Test("Enum option creates cycle tile with correct icon and color")
    func enumTileHasCorrectAppearance() {
        let tiles = CoreOptionTileProvider.tiles(from: EnumCore.options, coreClass: EnumCore.self)
        let enumTile = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })
        #expect(enumTile != nil)
        #expect(enumTile?.icon == "arrow.trianglehead.2.clockwise")
        #expect(enumTile?.colorKey == .cyan)
    }

    @Test("Enum tile badge shows current value title")
    func enumTileBadgeShowsTitle() {
        // No stored value — falls back to defaultValue 0 → first enum entry "8-bit"
        let tiles = CoreOptionTileProvider.tiles(from: EnumCore.options, coreClass: EnumCore.self)
        let enumTile = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })
        // Badge should be the title of the matching value, not description
        #expect(enumTile?.badge == "8-bit")
    }

    @Test("Enum tile longPressOptions count matches values")
    func enumTileLongPressOptionsCount() {
        let tiles = CoreOptionTileProvider.tiles(from: EnumCore.options, coreClass: EnumCore.self)
        let enumTile = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })
        // 3 enum values → 3 long-press options
        #expect(enumTile?.longPressOptions?.count == 3)
    }

    @Test("Enum tile longPressOptions use value title not description")
    func enumTileLongPressOptionsTitles() {
        let tiles = CoreOptionTileProvider.tiles(from: EnumCore.options, coreClass: EnumCore.self)
        let lp = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })?.longPressOptions
        let titles = lp?.map(\.title) ?? []
        // Should use .title ("8-bit", "16-bit", "32-bit"), not .description ("256 colors", etc.)
        #expect(titles == ["8-bit", "16-bit", "32-bit"])
    }

    @Test("selectValue sets enum option by title")
    func selectValueByTitle() {
        guard let option = CoreOptionTileProvider.findOption(key: "Color Depth", in: EnumCore.options) else {
            Issue.record("Could not find 'Color Depth' option")
            return
        }
        CoreOptionTileProvider.selectValue(titled: "16-bit", for: option, coreClass: EnumCore.self)
        let stored: Int? = EnumCore.valueForOption(option)
        #expect(stored == 1)
        // Clean up
        UserDefaults.standard.removeObject(forKey: "EnumCore.Color Depth")
    }

    @Test("selectValue does not match by description")
    func selectValueIgnoresDescription() {
        guard let option = CoreOptionTileProvider.findOption(key: "Color Depth", in: EnumCore.options) else {
            Issue.record("Could not find 'Color Depth' option")
            return
        }
        // "256 colors" is the description of the first value, not its title — should not match
        CoreOptionTileProvider.selectValue(titled: "256 colors", for: option, coreClass: EnumCore.self)
        // Value should remain at default (0) since "256 colors" matches no .title
        let stored: Int? = EnumCore.valueForOption(option)
        // No match means value unchanged (nil stored → default 0)
        #expect(stored == 0 || stored == nil)
        UserDefaults.standard.removeObject(forKey: "EnumCore.Color Depth")
    }
}

// MARK: - Multi Tile Tests

@Suite("CoreOptionTileProvider Multi Tile Tests")
struct CoreOptionTileProviderMultiTests {

    @Test("Multi option creates tile with list icon and purple color")
    func multiTileHasCorrectAppearance() {
        let tiles = CoreOptionTileProvider.tiles(from: MultiCore.options, coreClass: MultiCore.self)
        let multiTile = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })
        #expect(multiTile != nil)
        #expect(multiTile?.icon == "list.bullet.clipboard")
        #expect(multiTile?.colorKey == .purple)
    }

    @Test("Multi tile badge shows current value title")
    func multiTileBadgeShowsTitle() {
        UserDefaults.standard.removeObject(forKey: "MultiCore.System Region")
        let tiles = CoreOptionTileProvider.tiles(from: MultiCore.options, coreClass: MultiCore.self)
        let multiTile = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })
        // No stored value → first value "Auto"
        #expect(multiTile?.badge == "Auto")
    }

    @Test("Multi tile longPressOptions count matches values")
    func multiTileLongPressOptionsCount() {
        let tiles = CoreOptionTileProvider.tiles(from: MultiCore.options, coreClass: MultiCore.self)
        let multiTile = tiles.first(where: { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) })
        #expect(multiTile?.longPressOptions?.count == 3)
    }

    @Test("cycleNextValue stores String title for multi option")
    func cycleNextValueStoresStringTitle() {
        UserDefaults.standard.removeObject(forKey: "MultiCore.System Region")
        guard let option = CoreOptionTileProvider.findOption(key: "System Region", in: MultiCore.options) else {
            Issue.record("Could not find 'System Region' option")
            return
        }
        CoreOptionTileProvider.cycleNextValue(for: option, coreClass: MultiCore.self)
        // After cycling from default (index 0 "Auto"), should advance to index 1 "NTSC"
        let stored = UserDefaults.standard.string(forKey: "MultiCore.System Region")
        #expect(stored == "NTSC")
        UserDefaults.standard.removeObject(forKey: "MultiCore.System Region")
    }

    @Test("cycleNextValue wraps around at last multi value")
    func cycleNextValueWraps() {
        guard let option = CoreOptionTileProvider.findOption(key: "System Region", in: MultiCore.options) else {
            Issue.record("Could not find 'System Region' option")
            return
        }
        // Set to last value "PAL"
        CoreOptionTileProvider.selectValue(titled: "PAL", for: option, coreClass: MultiCore.self)
        CoreOptionTileProvider.cycleNextValue(for: option, coreClass: MultiCore.self)
        // Should wrap to first value "Auto"
        let stored = UserDefaults.standard.string(forKey: "MultiCore.System Region")
        #expect(stored == "Auto")
        UserDefaults.standard.removeObject(forKey: "MultiCore.System Region")
    }
}

// MARK: - Duplicate Title Tests

/// Regression tests for the duplicate-option-title scenario.
/// Cores like PVAzaharCore expose multiple enum options with the same display title
/// (e.g. "System Region" for primary and secondary sub-systems). Without positional
/// (index-based) lookup, tapping either tile would always act on the first match.
@Suite("CoreOptionTileProvider Duplicate Title Tests")
struct CoreOptionTileProviderDuplicateTitleTests {

    @Test("Two options with same title produce distinct tile IDs")
    func duplicateTitlesGetDistinctIDs() {
        let tiles = CoreOptionTileProvider.tiles(from: DuplicateTitleCore.options, coreClass: DuplicateTitleCore.self)
        let optionTiles = tiles.filter { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) }
        #expect(optionTiles.count == 2)
        // IDs must be distinct even though display titles are identical.
        #expect(optionTiles[0].id != optionTiles[1].id)
    }

    @Test("optionIndexAndKey returns distinct indices for duplicate-titled tiles")
    func optionIndexAndKeyDistinguishesDuplicates() {
        let tiles = CoreOptionTileProvider.tiles(from: DuplicateTitleCore.options, coreClass: DuplicateTitleCore.self)
        let optionTiles = tiles.filter { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) }
        guard optionTiles.count == 2 else {
            Issue.record("Expected 2 option tiles, got \(optionTiles.count)")
            return
        }
        let first = CoreOptionTileProvider.optionIndexAndKey(fromTileID: optionTiles[0].id)
        let second = CoreOptionTileProvider.optionIndexAndKey(fromTileID: optionTiles[1].id)
        #expect(first?.index == 0)
        #expect(second?.index == 1)
        // Both keys are the same display title.
        #expect(first?.key == second?.key)
    }

    @Test("findOption(atIndex:) returns second option for index 1 even with duplicate title")
    func findOptionAtIndexSelectsCorrectOption() {
        let tiles = CoreOptionTileProvider.tiles(from: DuplicateTitleCore.options, coreClass: DuplicateTitleCore.self)
        let optionTiles = tiles.filter { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) }
        guard optionTiles.count == 2 else {
            Issue.record("Expected 2 option tiles")
            return
        }
        // Tile at index 1 corresponds to the SECOND "System Region" enum (values: EU, JP).
        guard let (idx1, key1) = CoreOptionTileProvider.optionIndexAndKey(fromTileID: optionTiles[1].id) else {
            Issue.record("Could not parse index/key from second tile ID")
            return
        }
        let found = CoreOptionTileProvider.findOption(atIndex: idx1, key: key1, in: DuplicateTitleCore.options)
        // The second option's values are "EU" and "JP" — verify we didn't get the first option.
        if case let .enumeration(_, values, _, _) = found {
            let titles = values.map(\.title)
            #expect(titles == ["EU", "JP"])
        } else {
            Issue.record("Expected .enumeration for second System Region option")
        }
    }

    @Test("title-based findOption always returns the first duplicate")
    func findOptionByKeyReturnFirstMatch() {
        // This test documents the known limitation of title-based lookup:
        // it always returns the first option with a matching title.
        let found = CoreOptionTileProvider.findOption(key: "System Region", in: DuplicateTitleCore.options)
        if case let .enumeration(_, values, _, _) = found {
            let titles = values.map(\.title)
            // Should be the FIRST option's values (Auto, NTSC), not the second's (EU, JP).
            #expect(titles == ["Auto", "NTSC"])
        } else {
            Issue.record("Expected .enumeration for first System Region option")
        }
    }
}

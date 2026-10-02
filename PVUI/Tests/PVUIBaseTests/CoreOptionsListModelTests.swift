//
//  CoreOptionsListModelTests.swift
//  PVUIBaseTests
//
//  Layout, search and value access behind the core options list, plus the
//  category grouping the pause menu uses for the same options.
//

import Foundation
import Testing
import PVCoreBridge
@testable import PVUIBase

// MARK: - Fixtures

/// A core shaped like a large libretro one: loose options, categories, a
/// nested category, and an option repeated inside a category.
private final class ListMockCore: CoreOptional {
    static var currentGameMD5: String? { nil }

    static let frameskip = CoreOption.bool(
        CoreOptionValueDisplay(title: "Frameskip", description: "Skip frames to keep speed", storageKey: "mock_frameskip"),
        defaultValue: false
    )
    static let resolution = CoreOption.multi(
        CoreOptionValueDisplay(title: "Internal Resolution", description: "Render scale", storageKey: "mock_resolution"),
        values: [
            CoreOptionMultiValue(title: "Native (1x)", description: "1", isDefault: false),
            CoreOptionMultiValue(title: "Double (2x)", description: "2", isDefault: true),
            CoreOptionMultiValue(title: "Quad (4x)", description: "4", isDefault: false)
        ]
    )
    static let region = CoreOption.enumeration(
        CoreOptionValueDisplay(title: "Region", description: nil, storageKey: "mock_region"),
        values: [
            CoreOptionEnumValue(title: "Auto", description: nil, value: 0),
            CoreOptionEnumValue(title: "NTSC", description: nil, value: 10),
            CoreOptionEnumValue(title: "PAL", description: nil, value: 20)
        ],
        defaultValue: 0
    )
    static let volume = CoreOption.range(
        CoreOptionValueDisplay(title: "Volume", description: nil, storageKey: "mock_volume"),
        range: CoreOptionRange(defaultValue: 5, min: 0, max: 10),
        defaultValue: 5
    )
    static let interpolation = CoreOption.bool(
        CoreOptionValueDisplay(title: "Interpolation", description: "Smooth audio", storageKey: "mock_interpolation"),
        defaultValue: true
    )

    static let options: [CoreOption] = [
        frameskip,
        .group(CoreOptionValueDisplay(title: "Video", description: "Picture settings"), subOptions: [
            resolution,
            region,
            /// Same setting listed a second time; it must not get a second row.
            frameskip,
            .group(CoreOptionValueDisplay(title: "Hacks"), subOptions: [interpolation])
        ]),
        .group(CoreOptionValueDisplay(title: "Audio"), subOptions: [volume])
    ]

    static let storageKeys = ["mock_frameskip", "mock_resolution", "mock_region", "mock_volume", "mock_interpolation"]
    static let gameMD5 = "0123456789abcdef"

    /// Removes everything the tests may have saved, in both scopes.
    static func wipe() {
        let className = String(describing: ListMockCore.self)
        for key in storageKeys {
            UserDefaults.standard.removeObject(forKey: "\(className).\(key)")
            UserDefaults.standard.removeObject(forKey: "\(className).\(gameMD5).\(key)")
        }
    }
}

// MARK: - Layout

@Suite("CoreOptionListLayout")
struct CoreOptionListLayoutTests {

    private var sections: [CoreOptionListSection] {
        CoreOptionListLayout.sections(from: ListMockCore.options, generalTitle: "General")
    }

    @Test("Loose options lead in a General section; categories follow in the core's order")
    func sectionOrder() {
        #expect(sections.map(\.title) == ["General", "Video", "Video › Hacks", "Audio"])
    }

    @Test("A category's description is carried onto its section")
    func sectionDetail() {
        #expect(sections.first { $0.title == "Video" }?.detail == "Picture settings")
    }

    @Test("An option listed twice gets one row, where it first appears")
    func duplicatesCollapsed() {
        let titles = sections.flatMap(\.rows).map(\.title)
        #expect(titles.filter { $0 == "Frameskip" }.count == 1)
        #expect(sections.first?.rows.map(\.title) == ["Frameskip"])
        #expect(sections.first { $0.title == "Video" }?.rows.map(\.title) == ["Internal Resolution", "Region"])
    }

    @Test("Row and section identities are unique and the same on every build")
    func identitiesStable() {
        let first = sections
        let second = sections
        let rowIDs = first.flatMap(\.rows).map(\.id)
        #expect(Set(rowIDs).count == rowIDs.count)
        #expect(Set(first.map(\.id)).count == first.count)
        #expect(rowIDs == second.flatMap(\.rows).map(\.id))
    }

    @Test("A core with no options has no sections")
    func emptyCore() {
        #expect(CoreOptionListLayout.sections(from: [], generalTitle: "General").isEmpty)
    }

    // MARK: Search

    @Test("An empty query leaves the list untouched", arguments: ["", "   "])
    func emptyQuery(query: String) {
        #expect(CoreOptionListLayout.filter(sections, matching: query) == sections)
    }

    @Test("A query matches titles, descriptions, choices and category names",
          arguments: [
            ("resolution", ["Internal Resolution"]),
            ("SMOOTH", ["Interpolation"]),
            ("4x", ["Internal Resolution"]),
            ("pal", ["Region"]),
            ("audio", ["Interpolation", "Volume"]),
            ("video region", ["Region"])
          ])
    func queryMatches(query: String, expected: [String]) {
        let rows = CoreOptionListLayout.filter(sections, matching: query).flatMap(\.rows).map(\.title)
        #expect(rows == expected)
    }

    @Test("Sections with no matching rows disappear")
    func unmatchedSectionsDropped() {
        let filtered = CoreOptionListLayout.filter(sections, matching: "volume")
        #expect(filtered.map(\.title) == ["Audio"])
        let unmatched = CoreOptionListLayout.filter(sections, matching: "nothing matches this")
        #expect(unmatched.isEmpty)
    }

    // MARK: Collapsing

    @Test("A short list starts fully expanded")
    func smallListExpanded() {
        #expect(CoreOptionListLayout.initiallyCollapsedSectionIDs(for: sections).isEmpty)
    }

    @Test("A long, multi-category list starts with only its first section open")
    func largeListCollapsed() {
        let big: [CoreOption] = (0..<4).map { group in
            .group(CoreOptionValueDisplay(title: "Group \(group)"), subOptions: (0..<6).map { index in
                .bool(CoreOptionValueDisplay(title: "Option \(group)-\(index)"), defaultValue: false)
            })
        }
        let bigSections = CoreOptionListLayout.sections(from: big, generalTitle: "General")
        let collapsed = CoreOptionListLayout.initiallyCollapsedSectionIDs(for: bigSections)
        #expect(collapsed == Set(bigSections.dropFirst().map(\.id)))
    }
}

// MARK: - Values

/// Serialized: every test reads and writes the same UserDefaults keys.
@Suite("CoreOptionValueStore", .serialized)
struct CoreOptionValueStoreTests {

    private let global = CoreOptionValueStore(coreClass: ListMockCore.self, md5: nil)
    private let perGame = CoreOptionValueStore(coreClass: ListMockCore.self, md5: ListMockCore.gameMD5)

    init() {
        ListMockCore.wipe()
    }

    @Test("Untouched options report their defaults and are not marked modified")
    func defaults() {
        #expect(global.bool(ListMockCore.frameskip) == false)
        #expect(global.bool(ListMockCore.interpolation) == true)
        #expect(global.int(ListMockCore.region) == 0)
        #expect(global.int(ListMockCore.volume) == 5)
        #expect(global.multiIndex(ListMockCore.resolution) == 1)
        #expect(global.displayValue(ListMockCore.resolution) == "Double (2x)")
        #expect(!global.isModified(ListMockCore.resolution))
    }

    @Test("Activating flips a switch and advances a choice, wrapping at the end")
    func activate() {
        global.activate(ListMockCore.frameskip)
        #expect(global.bool(ListMockCore.frameskip))

        global.activate(ListMockCore.resolution)
        #expect(global.displayValue(ListMockCore.resolution) == "Quad (4x)")
        global.activate(ListMockCore.resolution)
        #expect(global.displayValue(ListMockCore.resolution) == "Native (1x)")
        ListMockCore.wipe()
    }

    @Test("Adjusting steps a value and stops at either end")
    func adjust() {
        global.adjust(ListMockCore.region, direction: 1)
        #expect(global.int(ListMockCore.region) == 10)
        global.adjust(ListMockCore.region, direction: -1)
        global.adjust(ListMockCore.region, direction: -1)
        #expect(global.int(ListMockCore.region) == 0)

        for _ in 0..<20 { global.adjust(ListMockCore.volume, direction: 1) }
        #expect(global.int(ListMockCore.volume) == 10)

        global.adjust(ListMockCore.frameskip, direction: 1)
        #expect(global.bool(ListMockCore.frameskip))
        global.adjust(ListMockCore.frameskip, direction: -1)
        #expect(!global.bool(ListMockCore.frameskip))
        ListMockCore.wipe()
    }

    @Test("A choice saved as a legacy index still resolves")
    func legacyMultiIndex() {
        ListMockCore.setValue(2, forOption: ListMockCore.resolution, andMD5: nil)
        #expect(global.displayValue(ListMockCore.resolution) == "Quad (4x)")
        ListMockCore.wipe()
    }

    @Test("A game override wins for that game, leaves the core-wide value alone, and reset removes it")
    func perGameOverrideAndReset() {
        global.setMulti(index: 0, for: ListMockCore.resolution)
        perGame.setMulti(index: 2, for: ListMockCore.resolution)

        #expect(perGame.displayValue(ListMockCore.resolution) == "Quad (4x)")
        #expect(global.displayValue(ListMockCore.resolution) == "Native (1x)")
        #expect(perGame.hasGameOverride(ListMockCore.resolution))

        perGame.reset(ListMockCore.resolution)
        #expect(!perGame.hasGameOverride(ListMockCore.resolution))
        #expect(perGame.displayValue(ListMockCore.resolution) == "Native (1x)")

        global.reset(ListMockCore.resolution)
        #expect(!global.isModified(ListMockCore.resolution))
        #expect(global.displayValue(ListMockCore.resolution) == "Double (2x)")
        ListMockCore.wipe()
    }
}

// MARK: - Pause menu grouping

@Suite("CoreOptionTileProvider grouping", .serialized)
struct CoreOptionTileGroupingTests {

    init() {
        ListMockCore.wipe()
    }

    @Test("Options keep their categories; range options have no cell")
    func groups() {
        let grouped = CoreOptionTileProvider.groupedTiles(from: ListMockCore.options, coreClass: ListMockCore.self, md5Scope: nil)
        #expect(grouped.ungrouped.map(\.label) == ["Frameskip"])
        /// "Audio" only holds a range, which the grid can't edit, so it is omitted.
        #expect(grouped.groups.map(\.title) == ["Video"])
        #expect(grouped.groups.first?.tiles.map(\.label) == ["Internal Resolution", "Region", "Frameskip", "Interpolation"])
    }

    @Test("Every grouped cell resolves back to the option it was built from")
    func idsResolve() {
        let grouped = CoreOptionTileProvider.groupedTiles(from: ListMockCore.options, coreClass: ListMockCore.self, md5Scope: nil)
        let flat = CoreOptionTileProvider.tiles(from: ListMockCore.options, coreClass: ListMockCore.self, md5Scope: nil)
            .filter { $0.id != CoreOptionTileProvider.coreSettingsTileID }
        let all = grouped.ungrouped + grouped.groups.flatMap(\.tiles)

        /// Same cells, same IDs as the flat list the handler indexes into.
        #expect(Set(all.map(\.id)) == Set(flat.map(\.id)))
        for cell in all {
            let parsed = CoreOptionTileProvider.optionIndexAndKey(fromTileID: cell.id)
            let option = parsed.flatMap {
                CoreOptionTileProvider.findOption(atIndex: $0.index, key: $0.key, in: ListMockCore.options)
            }
            #expect(option?.display.title == cell.label)
        }
    }

    @Test("A category named like the menu's own header is folded into the loose cells",
          arguments: ["Core", "CORE", " core "])
    func absorbsNamesakeCategory(categoryTitle: String) {
        let options: [CoreOption] = [
            ListMockCore.frameskip,
            .group(CoreOptionValueDisplay(title: categoryTitle), subOptions: [ListMockCore.interpolation]),
            .group(CoreOptionValueDisplay(title: "Video"), subOptions: [ListMockCore.region])
        ]
        let grouped = CoreOptionTileProvider.groupedTiles(from: options, coreClass: ListMockCore.self, md5Scope: nil)
        let absorbed = grouped.absorbingGroups(titled: "CORE")

        #expect(grouped.groups.map(\.title) == [categoryTitle, "Video"])
        #expect(absorbed.groups.map(\.title) == ["Video"])
        /// Loose cells first, then the absorbed category's, with IDs untouched.
        #expect(absorbed.ungrouped.map(\.label) == ["Frameskip", "Interpolation"])
        #expect(absorbed.ungrouped.map(\.id) == grouped.ungrouped.map(\.id) + grouped.groups[0].tiles.map(\.id))
    }

    @Test("Without a namesake category nothing moves")
    func absorbIsNoOpOtherwise() {
        let grouped = CoreOptionTileProvider.groupedTiles(from: ListMockCore.options, coreClass: ListMockCore.self, md5Scope: nil)
        #expect(grouped.absorbingGroups(titled: "CORE") == grouped)
    }
}

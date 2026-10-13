//
//  ShaderLibraryTests.swift
//  PVShadersTests
//

import Foundation
import Testing
import PVPrimitives
import PVSettings
@testable import PVShaders

@Suite("StampedMap")
struct StampedMapTests {
    @Test("a newer write wins in both merge directions")
    func newerWins() {
        var phone = StampedMap<Bool>()
        var tablet = StampedMap<Bool>()
        phone.set(true, for: "a", at: Date(timeIntervalSince1970: 10))
        tablet.set(nil, for: "a", at: Date(timeIntervalSince1970: 20))
        var mergedOnPhone = phone
        mergedOnPhone.merge(tablet)
        var mergedOnTablet = tablet
        mergedOnTablet.merge(phone)
        #expect(mergedOnPhone["a"] == nil)
        #expect(mergedOnTablet["a"] == nil)
        #expect(mergedOnPhone == mergedOnTablet)
    }

    @Test("favorites added on two devices are both kept")
    func unionOfAdds() {
        var phone = StampedMap<Bool>()
        var tablet = StampedMap<Bool>()
        phone.set(true, for: "slang:crt/a")
        tablet.set(true, for: "slang:crt/b")
        let changed = phone.merge(tablet)
        #expect(Set(phone.keys) == ["slang:crt/a", "slang:crt/b"])
        #expect(changed == ["slang:crt/b"])
    }

    @Test("a removal is not resurrected by an older copy")
    func tombstoneHolds() {
        var local = StampedMap<Bool>()
        local.set(true, for: "x", at: Date(timeIntervalSince1970: 1))
        let stale = local
        local.set(nil, for: "x", at: Date(timeIntervalSince1970: 2))
        local.merge(stale)
        #expect(local["x"] == nil)
    }

    @Test("pruning drops old tombstones and caps a prefix")
    func prune() {
        var map = StampedMap<Int>()
        map.set(nil, for: "gone", at: Date(timeIntervalSince1970: 1))
        for i in 0 ..< 5 { map.set(i, for: "game:\(i)", at: Date(timeIntervalSince1970: Double(100 + i))) }
        map.set(9, for: "global", at: Date(timeIntervalSince1970: 1))
        map.prune(tombstonesBefore: Date(timeIntervalSince1970: 50), prefix: "game:", limit: 2)
        #expect(map.entries["gone"] == nil)
        #expect(Set(map.keys) == ["game:4", "game:3", "global"])
    }
}

@Suite("ShaderSelection")
struct ShaderSelectionTests {
    @Test("every legacy filter mode converts and round-trips")
    func legacyRoundTrip() {
        for mode in MetalFilterModeOption.allCases {
            let selection = ShaderSelection(legacy: mode)
            #expect(selection.legacyMode == mode, "\(mode.rawValue)")
        }
    }

    @Test("auto picks by screen type")
    func autoByScreenType() {
        let selection = ShaderSelection.auto(crt: .slang("crt/crt-royale"), lcd: .native(.lcd))
        #expect(selection.shader(for: .crt) == .slang("crt/crt-royale"))
        #expect(selection.shader(for: .colorLCD) == .native(.lcd))
        #expect(selection.shader(for: .modern) == nil)
        #expect(ShaderSelection.skinFilter.shader(for: .crt) == nil)
    }

    @Test("a slang selection has no legacy equivalent")
    func slangHasNoLegacy() {
        #expect(ShaderSelection.always(.slang("crt/x")).legacyMode == nil)
    }
}

@Suite("ShaderLibraryStore")
@MainActor
struct ShaderLibraryStoreTests {
    private func makeStore(legacy: String? = nil) -> (ShaderLibraryStore, UserDefaults) {
        let suite = "ShaderLibraryStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("no defaults suite") }
        if let legacy { defaults.set(legacy, forKey: "metalFilterMode") }
        return (ShaderLibraryStore(defaults: defaults, catalog: ShaderCatalog(libraryURL: nil)), defaults)
    }

    @Test("game beats system beats global")
    func resolutionOrder() {
        let (store, _) = makeStore()
        store.setSelection(.always(.native(.vhs)), for: .global)
        store.setSelection(.always(.native(.lcd)), for: .system("com.provenance.gba"))
        store.setSelection(.off, for: .game("abc"))
        #expect(store.effectiveSelection(gameMD5: "abc", systemID: "com.provenance.gba") == .off)
        #expect(store.effectiveSelection(gameMD5: "zzz", systemID: "com.provenance.gba") == .always(.native(.lcd)))
        #expect(store.effectiveSelection(gameMD5: nil, systemID: "com.provenance.nes") == .always(.native(.vhs)))
        store.setSelection(nil, for: .game("abc"))
        #expect(store.effectiveScope(gameMD5: "abc", systemID: "com.provenance.gba") == .system("com.provenance.gba"))
    }

    @Test("the legacy filter mode becomes the global selection")
    func migratesLegacy() {
        let (store, _) = makeStore(legacy: "Auto(simpleCRT, lcd)")
        #expect(store.selection(for: .global) == .auto(crt: .native(.simpleCRT), lcd: .native(.lcd)))
    }

    @Test("slang parameter overrides store only non-default values, clamped")
    func parameterOverrides() {
        let (store, _) = makeStore()
        let shader = ShaderID.slang("crt/test")
        let parameter = ShaderParameterDescriptor(name: "mask", label: "Mask", initial: 0.5,
                                                  minimum: 0, maximum: 1, step: 0.1)
        store.setValue(3, of: parameter, in: shader)
        #expect(store.value(of: parameter, in: shader) == 1)
        #expect(store.isOverridden(parameter, in: shader))
        store.setValue(0.5, of: parameter, in: shader)
        #expect(store.parameters.values.isEmpty)
        #expect(!store.isOverridden(parameter, in: shader))
    }

    @Test("favorites and recents")
    func favoritesAndRecents() {
        let (store, _) = makeStore()
        store.toggleFavorite(.native(.vhs))
        #expect(store.isFavorite(.native(.vhs)))
        store.toggleFavorite(.native(.vhs))
        #expect(!store.isFavorite(.native(.vhs)))
        for i in 0 ..< ShaderLibraryStore.recentsLimit + 3 { store.noteUsed(.slang("x/\(i)")) }
        #expect(store.recents.count == ShaderLibraryStore.recentsLimit)
        #expect(store.recents.first == .slang("x/\(ShaderLibraryStore.recentsLimit + 2)"))
    }

    @Test("merging a remote favorites payload adds its entries")
    func mergeRemoteFavorites() throws {
        let (store, _) = makeStore()
        store.setFavorite(true, .native(.lcd))
        var remote = StampedMap<Bool>()
        remote.set(true, for: ShaderID.slang("crt/remote").rawValue)
        store.mergeFavorites(try JSONEncoder().encode(remote))
        #expect(Set(store.favoriteIDs) == [.native(.lcd), .slang("crt/remote")])
    }
}

@Suite("ShaderCatalog")
struct ShaderCatalogTests {
    static func libraryURL() throws -> URL {
        // A temporary library holding one fixture preset and a manifest for it.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fixtures = Bundle.module.bundleURL.appendingPathComponent("Fixtures")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("crt"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixtures.appendingPathComponent("crt-geom-mini"),
                                         to: root.appendingPathComponent("crt/crt-geom-mini"))
        let manifest = """
        {"formatVersion": 1, "presets": [
          {"id": "crt/crt-geom-mini", "name": "crt geom mini", "category": "crt", "passes": 2, "history": 0,
           "feedback": false, "luts": 0, "parameters": [
             {"name": "HDR", "label": "[ CRT ]", "initial": 0, "minimum": 0, "maximum": 0, "step": 0},
             {"name": "CURV", "label": "Curvature", "initial": 1, "minimum": 0, "maximum": 1, "step": 1}]},
          {"id": "misc/broken", "name": "broken", "category": "misc", "passes": 1, "history": 0,
           "feedback": false, "luts": 0, "parameters": [], "excluded": "load failed"}]}
        """
        try Data(manifest.utf8).write(to: root.appendingPathComponent("manifest.json"))
        return root
    }

    @Test("native filters come first; excluded presets are dropped")
    func loadsManifest() throws {
        let catalog = ShaderCatalog(libraryURL: try Self.libraryURL())
        #expect(catalog.entries.first?.id.kind == .native)
        #expect(catalog.entry(for: .slang("crt/crt-geom-mini")) != nil)
        #expect(catalog.entry(for: .slang("misc/broken")) == nil)
        #expect(catalog.categories.first == ShaderCatalog.nativeCategory)
    }

    @Test("parameters split at headings")
    func groups() throws {
        let catalog = ShaderCatalog(libraryURL: try Self.libraryURL())
        let entry = try #require(catalog.entry(for: .slang("crt/crt-geom-mini")))
        #expect(entry.parameterGroups.map(\.title) == ["CRT"])
        #expect(entry.editableParameters.map(\.name) == ["CURV"])
    }

    @Test("search matches every term across name, category and path, and filters by look")
    func search() throws {
        let catalog = ShaderCatalog(libraryURL: try Self.libraryURL())
        #expect(catalog.search("geom crt").map(\.id) == [.slang("crt/crt-geom-mini")])
        #expect(catalog.search("vhs").map(\.id) == [.native(.vhs)])
        #expect(catalog.search("", looks: [.lcd]).contains { $0.id == .native(.lcd) })
        #expect(!catalog.search("", looks: [.lcd]).contains { $0.id == .slang("crt/crt-geom-mini") })
    }

    @Test("every native filter has a descriptor per Defaults key")
    func nativeDescriptors() {
        for option in MetalFilterSelectionOption.allCases where option != .none {
            #expect(!NativeShaderParameters.descriptors(for: option).isEmpty, "\(option)")
        }
    }
}

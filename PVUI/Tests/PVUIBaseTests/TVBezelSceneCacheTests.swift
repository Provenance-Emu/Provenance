//
//  TVBezelSceneCacheTests.swift
//  PVUIBaseTests
//
//  Built TV scenes: the shared package's cache, and a scene as a shader of Provenance's library.
//

#if os(iOS) || os(tvOS)
import CoreGraphics
import Foundation
@testable import PVShaders
import SkinKitBezels
import Testing
@testable import PVUIBase

@Suite("TVBezelSceneCache")
struct TVBezelSceneCacheTests {

    private static let presetID = ShaderID.slang("test/tv")

    /// A scene told apart by one of its values.
    private func scene(_ revision: Int) -> TVBezelScene {
        TVBezelScene(key: "test", tubeRect: .zero, presetID: Self.presetID.rawValue,
                     values: ["revision": Float(revision)], borderPNG: nil)
    }

    @Test("A stored scene comes back, and an unknown key gives none")
    func roundTrip() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        #expect(cache.scene(for: "a")?.values["revision"] == 1)
        #expect(cache.scene(for: "b") == nil)
    }

    @Test("Past its capacity the least recently used scene goes")
    func evictsLeastRecentlyUsed() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        cache.store(scene(2), for: "b")
        cache.store(scene(3), for: "c")
        #expect(cache.scene(for: "a") == nil)
        #expect(cache.scene(for: "b")?.values["revision"] == 2)
        #expect(cache.scene(for: "c")?.values["revision"] == 3)
    }

    @Test("Reading a scene protects it from eviction")
    func readingRefreshes() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        cache.store(scene(2), for: "b")
        _ = cache.scene(for: "a")
        cache.store(scene(3), for: "c")
        #expect(cache.scene(for: "a")?.values["revision"] == 1)
        #expect(cache.scene(for: "b") == nil)
    }

    @Test("A scene becomes its preset in the shader library, with its values and its cabinet as the BORDER texture")
    func resolvesInLibrary() throws {
        // With no library on disk the catalogue still holds the built-in filters.
        let catalog = ShaderCatalog(libraryURL: nil)
        let entry = try #require(catalog.entries.first)
        let built = TVBezelScene(key: "living-room-tv|1920|false|false", tubeRect: .zero, presetID: entry.id.rawValue,
                                 values: ["fr_zoom": 40.5], borderPNG: Data([1, 2, 3]))
        let shader = try #require(built.resolvedShader(catalog: catalog))
        #expect(shader.entry.id == entry.id)
        #expect(shader.values == ["fr_zoom": 40.5])
        #expect(shader.revision == built.key.hashValue)
        #expect(built.textures == ShaderTextureOverrides(key: built.key, textures: [TVBezelShader.borderTextureName: Data([1, 2, 3])]))
        #expect(scene(4).textures == nil)
        // A preset the library does not have gives no shader: the picture shows alone.
        #expect(scene(4).resolvedShader(catalog: catalog) == nil)
    }
}
#endif

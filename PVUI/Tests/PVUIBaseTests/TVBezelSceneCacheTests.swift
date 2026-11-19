//
//  TVBezelSceneCacheTests.swift
//  PVUIBaseTests
//
//  The app-wide cache of built TV scenes.
//

#if os(iOS) || os(tvOS)
import CoreGraphics
@testable import PVShaders
import Testing
@testable import PVUIBase

@Suite("TVBezelSceneCache")
struct TVBezelSceneCacheTests {

    /// A scene told apart by its shader's revision.
    private func scene(_ revision: Int) -> TVBezelScene {
        let entry = ShaderCatalogEntry(id: .slang("test/tv"), name: "tv", category: "test", passes: 1,
                                       historyFrames: 0, usesFeedback: false, lutCount: 0, parameters: [],
                                       directory: nil)
        return TVBezelScene(tubeRect: .zero, shader: ResolvedShader(entry: entry, values: [:], revision: revision),
                            textures: nil)
    }

    @Test("A stored scene comes back, and an unknown key gives none")
    func roundTrip() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        #expect(cache.scene(for: "a")?.shader.revision == 1)
        #expect(cache.scene(for: "b") == nil)
    }

    @Test("Past its capacity the least recently used scene goes")
    func evictsLeastRecentlyUsed() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        cache.store(scene(2), for: "b")
        cache.store(scene(3), for: "c")
        #expect(cache.scene(for: "a") == nil)
        #expect(cache.scene(for: "b")?.shader.revision == 2)
        #expect(cache.scene(for: "c")?.shader.revision == 3)
    }

    @Test("Reading a scene protects it from eviction")
    func readingRefreshes() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        cache.store(scene(2), for: "b")
        _ = cache.scene(for: "a")
        cache.store(scene(3), for: "c")
        #expect(cache.scene(for: "a")?.shader.revision == 1)
        #expect(cache.scene(for: "b") == nil)
    }

    @Test("Storing a key again replaces its scene without growing the cache")
    func replaces() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        cache.store(scene(2), for: "a")
        cache.store(scene(3), for: "b")
        #expect(cache.scene(for: "a")?.shader.revision == 2)
        #expect(cache.scene(for: "b")?.shader.revision == 3)
    }

    @Test("Emptying the cache drops every scene")
    func empties() {
        let cache = TVBezelSceneCache(capacity: 2)
        cache.store(scene(1), for: "a")
        cache.removeAll()
        #expect(cache.scene(for: "a") == nil)
    }
}
#endif

import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayLayoutStore") @MainActor
struct OverlayLayoutStoreTests {
    static func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    let key = "com.provenance.snes.standard.portrait"
    let move = OverlayLayoutOverrides(groups: [
        "face": GroupOverride(center: AnchoredCenter(h: .max, x: 50, v: .max, y: 60),
                              scale: nil, opacity: nil, buttons: [:])
    ])

    @Test("Per-game overrides win over pad-kind overrides, which win over empty")
    func fallback() {
        let store = OverlayLayoutStore(fileURL: Self.tempURL())
        #expect(store.overrides(for: key, gameMD5: "abc") == .empty)
        store.set(move, for: key, gameMD5: nil)
        #expect(store.overrides(for: key, gameMD5: "abc") == move)
        var perGame = move
        perGame.groups["face"]?.opacity = 0.4
        store.set(perGame, for: key, gameMD5: "abc")
        #expect(store.overrides(for: key, gameMD5: "abc") == perGame)
        #expect(store.overrides(for: key, gameMD5: "other") == move)
    }

    @Test("Writes persist to disk and reload")
    func persists() {
        let url = Self.tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let first = OverlayLayoutStore(fileURL: url)
        first.set(move, for: key, gameMD5: nil)
        let second = OverlayLayoutStore(fileURL: url)
        #expect(second.overrides(for: key, gameMD5: nil) == move)
        #expect(second.snapshot().version == OverlayLayoutStore.currentVersion)
    }

    @Test("Reset removes only the requested layer and bumps revision")
    func reset() {
        let store = OverlayLayoutStore(fileURL: Self.tempURL())
        store.set(move, for: key, gameMD5: nil)
        store.set(move, for: key, gameMD5: "abc")
        let rev = store.revision
        store.reset(key: key, gameMD5: "abc")
        #expect(store.overrides(for: key, gameMD5: "abc") == move)
        store.reset(key: key, gameMD5: nil)
        #expect(store.overrides(for: key, gameMD5: "abc") == .empty)
        #expect(store.revision > rev)
    }
}

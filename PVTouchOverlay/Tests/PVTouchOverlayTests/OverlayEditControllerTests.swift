import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayEditController") @MainActor
struct OverlayEditControllerTests {
    let canvas = OverlayLayoutEngineTests.phonePortrait
    let key = "com.provenance.snes.standard.portrait"

    func make() -> (OverlayEditController, OverlayLayoutStore) {
        let store = OverlayLayoutStore(fileURL: OverlayLayoutStoreTests.tempURL())
        return (OverlayEditController(store: store, key: key, gameMD5: nil, canvas: canvas), store)
    }

    @Test("Moving a group stores an anchored centre; undo removes it")
    func move() {
        let (controller, store) = make()
        controller.moveGroup("face", to: CGPoint(x: 330, y: 780))
        let override = store.overrides(for: key, gameMD5: nil).groups["face"]
        #expect(override?.center == AnchoredCenter(h: .max, x: 60, v: .max, y: 64))
        controller.undo()
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"] == nil)
    }

    @Test("Scaling multiplies and clamps to the engine range")
    func scale() {
        let (controller, store) = make()
        controller.scaleGroup("face", by: 1.5)
        controller.scaleGroup("face", by: 1.5)
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"]?.scale == CGSize(width: 2, height: 2))
    }

    @Test("Detach then move records a per-control offset; reattach clears it")
    func detach() {
        let (controller, store) = make()
        controller.detachControl(groupID: "face", controlID: "a")
        controller.moveControl(groupID: "face", controlID: "a", by: CGPoint(x: 10, y: -5))
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"]?.buttons["a"]?.offset
                == CGPoint(x: 10, y: -5))
        controller.reattachControl(groupID: "face", controlID: "a")
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"]?.buttons["a"] == nil)
    }

    @Test("Cancel restores the state at entry")
    func cancel() {
        let (controller, store) = make()
        controller.setOpacity("face", 0.3)
        controller.cancel()
        #expect(store.overrides(for: key, gameMD5: nil) == .empty)
    }

    @Test("Undo and redo keep the derived detached set in sync")
    func detachedFollowsUndo() {
        let (controller, _) = make()
        controller.detachControl(groupID: "face", controlID: "a")
        #expect(controller.detached == ["face/a"])
        controller.undo()
        #expect(controller.detached.isEmpty)
        controller.redo()
        #expect(controller.detached == ["face/a"])
    }

    @Test("One interaction is one undo step; revision still bumps per mutation")
    func interactionCoalesces() {
        let (controller, store) = make()
        let before = store.revision
        controller.beginInteraction()
        for step in 1...10 { controller.moveGroup("face", to: CGPoint(x: 200 + CGFloat(step), y: 700)) }
        controller.endInteraction()
        #expect(store.revision - before == 10)
        #expect(controller.revision == store.revision)
        controller.undo()
        #expect(store.overrides(for: key, gameMD5: nil) == .empty)
        #expect(!controller.canUndo)
    }

    @Test("Interaction defers the disk write until it ends")
    func interactionPersistsOnce() throws {
        let url = OverlayLayoutStoreTests.tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = OverlayLayoutStore(fileURL: url)
        let controller = OverlayEditController(store: store, key: key, gameMD5: nil, canvas: canvas)
        controller.beginInteraction()
        controller.moveGroup("face", to: CGPoint(x: 300, y: 700))
        #expect(!FileManager.default.fileExists(atPath: url.path))
        controller.endInteraction()
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Authored group scale is the base when no override exists")
    func authoredScaleBase() {
        let store = OverlayLayoutStore(fileURL: OverlayLayoutStoreTests.tempURL())
        let controller = OverlayEditController(
            store: store, key: key, gameMD5: nil, canvas: canvas,
            groupDefaults: ["face": (scale: CGSize(width: 1.2, height: 1.2), opacity: 0.8)])
        controller.scaleGroup("face", by: 1.5)
        let scale = store.overrides(for: key, gameMD5: nil).groups["face"]?.scale
        #expect(abs((scale?.width ?? 0) - 1.8) < 0.0001)
        controller.setScale("face", 5)
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"]?.scale == CGSize(width: 2, height: 2))
    }

    @Test("Done ends an open interaction and writes the edit to disk")
    func doneFlushesOpenInteraction() {
        let url = OverlayLayoutStoreTests.tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = OverlayLayoutStore(fileURL: url)
        let controller = OverlayEditController(store: store, key: key, gameMD5: nil, canvas: canvas)
        controller.beginInteraction()
        controller.moveGroup("face", to: CGPoint(x: 300, y: 700))
        controller.done()
        let reloaded = OverlayLayoutStore(fileURL: url)
        #expect(reloaded.overrides(for: key, gameMD5: nil).groups["face"]?.center != nil)
        #expect(!controller.canUndo)
    }
}

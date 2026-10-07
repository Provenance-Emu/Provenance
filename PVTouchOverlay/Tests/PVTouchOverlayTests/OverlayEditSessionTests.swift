import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayEditSession") @MainActor
struct OverlayEditSessionTests {
    private func scaled(_ value: CGFloat) -> OverlayLayoutOverrides {
        OverlayLayoutOverrides(groups: [
            "face": GroupOverride(center: nil, scale: CGSize(width: value, height: value),
                                  opacity: nil, buttons: [:])
        ])
    }

    @Test("Undo and redo walk store snapshots; cancel restores the entry state")
    func undoRedo() {
        let store = OverlayLayoutStore(fileURL: OverlayLayoutStoreTests.tempURL())
        let key = "com.provenance.snes.standard.portrait"
        let session = OverlayEditSession(store: store, key: key, gameMD5: nil)
        let first = scaled(1.2)
        let second = scaled(1.5)
        session.record(); store.set(first, for: key, gameMD5: nil)
        session.record(); store.set(second, for: key, gameMD5: nil)
        #expect(session.canUndo)
        #expect(session.undo()); #expect(store.overrides(for: key, gameMD5: nil) == first)
        #expect(session.undo()); #expect(store.overrides(for: key, gameMD5: nil) == .empty)
        #expect(!session.undo())
        #expect(session.redo()); #expect(store.overrides(for: key, gameMD5: nil) == first)
        session.cancel()
        #expect(store.overrides(for: key, gameMD5: nil) == .empty)
    }
}

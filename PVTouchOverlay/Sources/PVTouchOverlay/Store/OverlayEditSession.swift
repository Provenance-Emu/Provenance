import Foundation

/// Undo/redo over whole-store snapshots for one edit session. History is not persisted.
@MainActor
public final class OverlayEditSession {
    private let store: OverlayLayoutStore
    public let key: String
    public let gameMD5: String?
    private let entrySnapshot: OverlayLayoutFile
    private var undoStack: [OverlayLayoutFile] = []
    private var redoStack: [OverlayLayoutFile] = []

    public init(store: OverlayLayoutStore, key: String, gameMD5: String?) {
        self.store = store
        self.key = key
        self.gameMD5 = gameMD5
        self.entrySnapshot = store.snapshot()
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call before a mutation.
    public func record() { undoStack.append(store.snapshot()); redoStack.removeAll() }

    @discardableResult public func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(store.snapshot())
        store.restore(previous)
        return true
    }

    @discardableResult public func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(store.snapshot())
        store.restore(next)
        return true
    }

    public func cancel() { store.restore(entrySnapshot); undoStack.removeAll(); redoStack.removeAll() }
    public func commit() { undoStack.removeAll(); redoStack.removeAll() }
}

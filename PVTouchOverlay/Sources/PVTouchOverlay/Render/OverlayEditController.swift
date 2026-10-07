import Foundation
import Observation
import CoreGraphics

/// Edit-mode state and mutations. Pure: every change goes through the store so the host re-resolves.
@MainActor @Observable
public final class OverlayEditController {
    /// Template-authored scale and opacity for a group, used as the base when no override exists.
    public typealias GroupDefaults = (scale: CGSize, opacity: CGFloat)

    public var selectedGroupID: String?
    public var selectedControlID: String?
    /// Mirrors the store's revision after every mutation, undo, redo and cancel so views re-render.
    public private(set) var revision: Int
    public let canvas: OverlayCanvas
    @ObservationIgnored private let store: OverlayLayoutStore
    @ObservationIgnored private let session: OverlayEditSession
    @ObservationIgnored private let key: String
    @ObservationIgnored private let gameMD5: String?
    @ObservationIgnored private let groupDefaults: [String: GroupDefaults]
    @ObservationIgnored private var inInteraction = false

    public init(store: OverlayLayoutStore, key: String, gameMD5: String?, canvas: OverlayCanvas,
                groupDefaults: [String: GroupDefaults] = [:]) {
        self.store = store
        self.key = key
        self.gameMD5 = gameMD5
        self.canvas = canvas
        self.groupDefaults = groupDefaults
        self.session = OverlayEditSession(store: store, key: key, gameMD5: gameMD5)
        self.revision = store.revision
    }

    public var canUndo: Bool { session.canUndo }
    public var canRedo: Bool { session.canRedo }
    public var overrides: OverlayLayoutOverrides { store.overrides(for: key, gameMD5: gameMD5) }

    /// "group/control" keys of controls that carry their own override; derived so undo/redo stay in sync.
    public var detached: Set<String> {
        _ = revision
        var keys = Set<String>()
        for (groupID, override) in overrides.groups {
            for controlID in override.buttons.keys { keys.insert("\(groupID)/\(controlID)") }
        }
        return keys
    }

    /// Scale shown for a group: the override, else the template's authored scale.
    public func effectiveScale(_ id: String) -> CGSize {
        overrides.groups[id]?.scale ?? groupDefaults[id]?.scale ?? CGSize(width: 1, height: 1)
    }

    /// Opacity shown for a group. The engine multiplies the template opacity by the override.
    public func effectiveOpacity(_ id: String) -> CGFloat {
        (groupDefaults[id]?.opacity ?? 1) * (overrides.groups[id]?.opacity ?? 1)
    }

    /// Groups the changes of one gesture into a single undo step and a single disk write.
    public func beginInteraction() {
        guard !inInteraction else { return }
        inInteraction = true
        session.record()
    }

    public func endInteraction() {
        guard inInteraction else { return }
        inInteraction = false
        store.flush()
    }

    private func apply(_ updated: OverlayLayoutOverrides) {
        if inInteraction {
            store.set(updated, for: key, gameMD5: gameMD5, persist: false)
        } else {
            session.record()
            store.set(updated, for: key, gameMD5: gameMD5)
        }
        revision = store.revision
    }

    private func mutate(_ groupID: String, _ body: (inout GroupOverride) -> Void) {
        var all = overrides
        var group = all.groups[groupID] ?? .empty
        body(&group)
        all.groups[groupID] = group
        apply(all)
    }

    public func moveGroup(_ id: String, to center: CGPoint) {
        let anchored = AnchoredCenter.make(center: center, in: canvas)
        mutate(id) { $0.center = anchored }
    }

    public func scaleGroup(_ id: String, by factor: CGFloat) {
        let current = effectiveScale(id)
        setScale(id, CGSize(width: current.width * factor, height: current.height * factor))
    }

    public func setScale(_ id: String, _ value: CGFloat) {
        setScale(id, CGSize(width: value, height: value))
    }

    private func setScale(_ id: String, _ value: CGSize) {
        mutate(id) { $0.scale = OverlayLayoutEngine.clampedScale(value) }
    }

    /// `value` is the desired effective opacity; stored as a multiplier over the template's authored opacity.
    public func setOpacity(_ id: String, _ value: CGFloat) {
        let base = max(groupDefaults[id]?.opacity ?? 1, 0.01)
        mutate(id) { $0.opacity = min(max(value / base, 0.1), 1) }
    }

    public func detachControl(groupID: String, controlID: String) {
        mutate(groupID) { if $0.buttons[controlID] == nil { $0.buttons[controlID] = ControlOverride() } }
    }

    public func moveControl(groupID: String, controlID: String, by delta: CGPoint) {
        mutate(groupID) {
            var control = $0.buttons[controlID] ?? ControlOverride()
            control.offset = CGPoint(x: control.offset.x + delta.x, y: control.offset.y + delta.y)
            $0.buttons[controlID] = control
        }
    }

    public func reattachControl(groupID: String, controlID: String) {
        mutate(groupID) { $0.buttons[controlID] = nil }
    }

    public func resetGroup(_ id: String) {
        var all = overrides
        all.groups[id] = nil
        apply(all)
    }

    public func resetAll() {
        session.record()
        store.reset(key: key, gameMD5: gameMD5)
        revision = store.revision
    }

    public func undo() { session.undo(); revision = store.revision }
    public func redo() { session.redo(); revision = store.revision }
    public func cancel() { session.cancel(); revision = store.revision }
    /// Ends a gesture still in flight, keeps the edits and writes them to disk.
    public func done() {
        endInteraction()
        session.commit()
        store.flush()
    }
}

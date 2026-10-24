import Foundation
import CoreGraphics
import SkinKitUI

/// Per-touch state for one overlay cluster: decides which controls the live touches press.
///
/// - Drag across: every event recomputes the union of controls under all live touches, so a finger
///   sliding from one gameplay control onto another releases the first and presses the second.
/// - Multi-button touch: with `multiButton`, a touch on a plain gameplay button also presses the
///   neighbouring gameplay buttons its contact circle covers (`OverlayMultiButtonTouch`).
/// - Lockout: who owns a touch is decided once, at touch-down, by the plain nearest-control rule. A touch
///   that goes down on a system control (`TouchInputRole.system`) holds only that control while it stays
///   inside its hit frame; once it leaves, it presses nothing until it lifts, even if it comes back. Any
///   other touch only ever reaches gameplay controls, and system controls never join a multi-button press.
///
/// Pure value type so the rules are testable without UIKit; `OverlayTouchCluster` feeds it touches.
public struct OverlayTouchTracker<Key: Hashable> {
    public enum Owner: Equatable, Sendable {
        /// May press gameplay controls only.
        case gameplay
        /// Went down on this system control and is latched to it.
        case system(id: String)
        /// Left the system control it went down on; presses nothing until it lifts.
        case inert
    }

    struct Touch {
        var location: CGPoint
        var radius: CGFloat
        var owner: Owner
    }

    public var controls: [ResolvedControl] {
        didSet { dropVanishedLatches() }
    }
    public var multiButton: Bool

    private var touches: [Key: Touch] = [:]
    private var dpadState: [String: Set<OverlayDPadDirection>] = [:]

    public init(controls: [ResolvedControl] = [], multiButton: Bool = false) {
        self.controls = controls
        self.multiButton = multiButton
    }

    public var isEmpty: Bool { touches.isEmpty }

    /// Keys of the live touches.
    public var keys: Set<Key> { Set(touches.keys) }

    public func owner(of key: Key) -> Owner? { touches[key]?.owner }

    public mutating func began(_ key: Key, at location: CGPoint, radius: CGFloat = 0) {
        let owner: Owner
        if let target = OverlayHitTester.topControl(at: location, in: controls),
           target.control.touchRole == .system {
            owner = .system(id: target.id)
        } else {
            owner = .gameplay
        }
        touches[key] = Touch(location: location, radius: radius, owner: owner)
    }

    public mutating func moved(_ key: Key, to location: CGPoint, radius: CGFloat = 0) {
        guard var touch = touches[key] else { return }
        touch.location = location
        touch.radius = radius
        if case .system(let id) = touch.owner,
           controls.first(where: { $0.id == id })?.hitFrame.contains(location) != true {
            touch.owner = .inert
        }
        touches[key] = touch
    }

    public mutating func ended(_ key: Key) {
        touches[key] = nil
    }

    public mutating func removeAll() {
        touches.removeAll()
    }

    /// The controls the live touches press now. Updates the d-pad hysteresis state.
    public mutating func hits() -> Set<OverlayHit> {
        let gameplay = controls.filter { $0.control.touchRole == .gameplay }
        let eligible = gameplay.filter { $0.control.isMultiPressEligible }
        var result = Set<OverlayHit>()
        for touch in touches.values {
            switch touch.owner {
            case .inert:
                continue
            case .system(let id):
                result.insert(.control(id: id))
            case .gameplay:
                result.formUnion(gameplayHits(for: touch, gameplay: gameplay, eligible: eligible))
            }
        }
        var next: [String: Set<OverlayDPadDirection>] = [:]
        for case let .dpad(id, direction) in result { next[id, default: []].insert(direction) }
        dpadState = next
        return result
    }

    private func gameplayHits(for touch: Touch, gameplay: [ResolvedControl],
                              eligible: [ResolvedControl]) -> Set<OverlayHit> {
        let target = OverlayHitTester.topControl(at: touch.location, in: gameplay)
        if let target, case .dpad = target.control.kind {
            let directions = OverlayHitTester.dpadDirections(point: touch.location, in: target.frame,
                                                             previous: dpadState[target.id] ?? [])
            return Set(directions.map { .dpad(id: target.id, $0) })
        }
        var result = Set<OverlayHit>()
        if let target { result.insert(.control(id: target.id)) }
        // A stick or other non-plain winner stays alone; so does every touch in single-button mode.
        guard multiButton, target.map({ $0.control.isMultiPressEligible }) ?? true else { return result }
        for id in OverlayMultiButtonTouch.hits(at: touch.location, touchRadius: touch.radius, controls: eligible) {
            result.insert(.control(id: id))
        }
        return result
    }

    /// A latch whose control vanished in a relayout can never fire again.
    private mutating func dropVanishedLatches() {
        let ids = Set(controls.map(\.id))
        for (key, touch) in touches {
            if case .system(let id) = touch.owner, !ids.contains(id) { touches[key]?.owner = .inert }
        }
    }
}

import Foundation
import CoreGraphics

public enum OverlaySurfacePhase: Sendable { case began, moved, ended }

public protocol OverlayInputSink: AnyObject {
    func overlayPress(_ id: OverlayInputID)
    func overlayRelease(_ id: OverlayInputID)
    /// -1...1, +y = up.
    func overlayStick(_ side: OverlayStickSide, x horizontal: Float, y vertical: Float)
    /// 0...1.
    func overlayAnalogTrigger(_ id: OverlayInputID, value: Float)
    func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase)
    func overlayAction(_ action: OverlayAction)
    func overlayHardwareSwitch(descriptorID: String, isOn: Bool)
}

/// Turns hit-set deltas into sink calls. Each touch surface reports its own partial hit set under a
/// source key; the dispatcher acts on the union across sources. Releases go first, then presses, each in a
/// stable order (control id, then d-pad direction). Tokens are reference-counted, so a token bound to two
/// held controls is released only when both let go.
public final class OverlayHitDispatcher {
    private var controls: [String: OverlayControl]
    private weak var sink: (any OverlayInputSink)?
    private var sources: [String: Set<OverlayHit>] = [:]
    private var current = Set<OverlayHit>()
    private var tokenCounts: [OverlayInputID: Int] = [:]

    public init(controls: [OverlayControl], sink: any OverlayInputSink) {
        self.controls = Self.index(controls)
        self.sink = sink
    }

    /// Swaps the control table after a relayout. Held hits whose controls vanished are released first.
    public func update(controls newControls: [OverlayControl]) {
        let table = Self.index(newControls)
        let vanished = current.filter { table[Self.controlID($0)] == nil }.sorted(by: Self.isOrdered)
        for hit in vanished { emit(hit, isDown: false) }
        current.subtract(vanished)
        for key in Array(sources.keys) {
            sources[key]?.subtract(vanished)
            if sources[key]?.isEmpty == true { sources[key] = nil }
        }
        controls = table
    }

    /// Replaces the hits held by one surface and emits the delta of the union across all surfaces.
    public func apply(_ hits: Set<OverlayHit>, from source: String) {
        sources[source] = hits.isEmpty ? nil : hits
        let union = sources.values.reduce(into: Set<OverlayHit>()) { $0.formUnion($1) }
        let released = current.subtracting(union).sorted(by: Self.isOrdered)
        let pressed = union.subtracting(current).sorted(by: Self.isOrdered)
        current = union
        for hit in released { emit(hit, isDown: false) }
        for hit in pressed { emit(hit, isDown: true) }
    }

    public func releaseAll() {
        let released = current.sorted(by: Self.isOrdered)
        sources.removeAll()
        current.removeAll()
        for hit in released { emit(hit, isDown: false) }
    }

    private static func index(_ controls: [OverlayControl]) -> [String: OverlayControl] {
        Dictionary(controls.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func controlID(_ hit: OverlayHit) -> String {
        switch hit {
        case .control(let id): return id
        case .dpad(let id, _): return id
        }
    }

    private static func sortKey(_ hit: OverlayHit) -> (String, Int) {
        switch hit {
        case .control(let id): return (id, 0)
        case .dpad(let id, let direction):
            return (id, (OverlayDPadDirection.allCases.firstIndex(of: direction) ?? 0) + 1)
        }
    }

    private static func isOrdered(_ lhs: OverlayHit, _ rhs: OverlayHit) -> Bool {
        let left = sortKey(lhs), right = sortKey(rhs)
        return left.0 == right.0 ? left.1 < right.1 : left.0 < right.0
    }

    private func emit(_ hit: OverlayHit, isDown: Bool) {
        guard let sink else { return }
        switch hit {
        case .dpad(let id, let direction):
            guard case .dpad(let upToken, let downToken, let leftToken, let rightToken)? = controls[id]?.kind else {
                return
            }
            let tokens: [OverlayDPadDirection: OverlayInputID] = [
                .up: upToken, .down: downToken, .left: leftToken, .right: rightToken
            ]
            if let token = tokens[direction] { emitToken(token, isDown: isDown, analog: false, to: sink) }
        case .control(let id):
            guard let kind = controls[id]?.kind else { return }
            switch kind {
            case .button(let token):
                emitToken(token, isDown: isDown, analog: false, to: sink)
            case .analogTrigger(let token):
                emitToken(token, isDown: isDown, analog: true, to: sink)
            case .action(let action):
                if isDown { sink.overlayAction(action) }
            case .stick, .touchSurface, .hardwareSwitch, .dpad:
                break // handled by their own surfaces/views
            }
        }
    }

    /// Reference-counted: the sink sees 0->1 as down and 1->0 as up.
    private func emitToken(_ token: OverlayInputID, isDown: Bool, analog: Bool, to sink: any OverlayInputSink) {
        let before = tokenCounts[token, default: 0]
        let after = isDown ? before + 1 : max(before - 1, 0)
        tokenCounts[token] = after == 0 ? nil : after
        guard (before == 0) != (after == 0) else { return }
        if analog {
            sink.overlayAnalogTrigger(token, value: isDown ? 1 : 0)
        } else if isDown {
            sink.overlayPress(token)
        } else {
            sink.overlayRelease(token)
        }
    }
}

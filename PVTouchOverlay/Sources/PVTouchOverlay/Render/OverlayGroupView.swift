#if canImport(UIKit)
import SwiftUI
import UIKit
import PVSettings

/// UIKit cluster surface bridged into SwiftUI. Controls are in canvas points; the
/// representable is laid out at the group's frame, so `origin` is the group origin.
struct OverlayClusterRepresentable: UIViewRepresentable {
    let controls: [ResolvedControl]
    let origin: CGPoint
    let onChange: (Set<OverlayHit>) -> Void

    func makeUIView(context: Context) -> OverlayTouchCluster {
        let view = OverlayTouchCluster(frame: .zero)
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: OverlayTouchCluster, context: Context) {
        view.controls = controls
        view.canvasOrigin = origin
        view.onChange = onChange
    }

    static func dismantleUIView(_ view: OverlayTouchCluster, coordinator: ()) { view.releaseAll() }
}

struct OverlaySurfaceRepresentable: UIViewRepresentable {
    let onBegan: (CGPoint) -> Void
    let onMoved: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeUIView(context: Context) -> OverlaySingleTouchSurface {
        let view = OverlaySingleTouchSurface(frame: .zero)
        view.onBegan = onBegan
        view.onMoved = onMoved
        view.onEnded = onEnded
        return view
    }

    func updateUIView(_ view: OverlaySingleTouchSurface, context: Context) {
        view.onBegan = onBegan
        view.onMoved = onMoved
        view.onEnded = onEnded
    }

    static func dismantleUIView(_ view: OverlaySingleTouchSurface, coordinator: ()) { view.releaseAll() }
}

/// Draws one resolved group: art layer (never redraws on press) + touch layer.
struct OverlayGroupView: View {
    private static let knobTravelFraction: CGFloat = 0.3
    /// How long a stick click is held, so a core polling once per frame sees it.
    private static let stickClickHold: TimeInterval = 0.1

    let group: ResolvedGroup
    let palette: OverlayPalette
    let style: OverlayStyle
    let dispatcher: OverlayHitDispatcher
    let sink: any OverlayInputSink
    let hapticIntensity: Double
    let editing: Bool
    @State private var pressedState = OverlayPressedState()
    @State private var knob = OverlayKnobState()
    @State private var clickDetectors: [OverlayStickSide: OverlayStickClickDetector] = [:]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(group.controls) { control in
                controlArt(control)
                    .frame(width: control.frame.width, height: control.frame.height)
                    .offset(x: control.frame.minX - group.frame.minX, y: control.frame.minY - group.frame.minY)
                    .allowsHitTesting(false)
            }
            touchLayer
        }
        .frame(width: group.frame.width, height: group.frame.height, alignment: .topLeading)
        .opacity(group.opacity)
        .onChange(of: editing) { _, isEditing in
            guard isEditing else { return }
            pressedState.pressed = []
            knob.offset = .zero
            for control in stickControls {
                if case .stick(let side, _) = control.control.kind { sink.overlayStick(side, x: 0, y: 0) }
            }
        }
    }

    @ViewBuilder private func controlArt(_ control: ResolvedControl) -> some View {
        let spec = OverlayArtSpec(shape: control.control.shape, color: palette.color(for: control.control.paletteSlot),
                                  labelColor: palette.label, style: style,
                                  pressed: pressedState.pressed.contains(control.id), label: control.control.label)
        if case .stick = control.control.kind {
            OverlayStickArt(spec: spec, knob: knob, axis: control.control.axis).equatable()
        } else {
            OverlayControlArt(spec: spec).equatable()
        }
    }

    private var clusterControls: [ResolvedControl] {
        group.controls.filter { control in
            switch control.control.kind {
            case .stick, .touchSurface, .hardwareSwitch: return false
            default: return true
            }
        }
    }

    /// Union of the cluster controls' hit frames, so touches in an extended-edge outset reach the UIKit view.
    private var clusterHitFrame: CGRect? {
        let union = clusterControls.map(\.hitFrame).reduce(CGRect.null) { $0.union($1) }
        return union.isNull ? nil : union
    }

    private var stickControls: [ResolvedControl] {
        group.controls.filter { if case .stick = $0.control.kind { return true } else { return false } }
    }

    @ViewBuilder private var touchLayer: some View {
        if let clusterFrame = clusterHitFrame {
            OverlayClusterRepresentable(controls: clusterControls, origin: clusterFrame.origin) { hits in
                handle(hits)
            }
            .frame(width: clusterFrame.width, height: clusterFrame.height)
            .offset(x: clusterFrame.minX - group.frame.minX, y: clusterFrame.minY - group.frame.minY)
        }
        ForEach(stickControls) { control in
            if case .stick(let side, let click) = control.control.kind {
                OverlaySurfaceRepresentable(
                    onBegan: { point in
                        var detector = OverlayStickClickDetector(radius: control.frame.width / 2)
                        detector.began(at: hitPoint(point, control), time: ProcessInfo.processInfo.systemUptime)
                        clickDetectors[side] = detector
                        moveStick(side, point, control)
                    },
                    onMoved: { point in
                        clickDetectors[side]?.moved(to: hitPoint(point, control))
                        moveStick(side, point, control)
                    },
                    onEnded: {
                        knob.offset = .zero
                        sink.overlayStick(side, x: 0, y: 0)
                        let clicked = clickDetectors[side]?.ended(at: ProcessInfo.processInfo.systemUptime) ?? false
                        if clicked, let click { pressStickClick(click) }
                    })
                .frame(width: control.hitFrame.width, height: control.hitFrame.height)
                .offset(x: control.hitFrame.minX - group.frame.minX, y: control.hitFrame.minY - group.frame.minY)
            }
        }
    }

    private func handle(_ hits: Set<OverlayHit>) {
        let before = pressedState.pressed
        dispatcher.apply(hits, from: group.id)
        var now = Set<String>()
        for hit in hits {
            switch hit {
            case .control(let id): now.insert(id)
            case .dpad(let id, _): now.insert(id)
            }
        }
        guard now != before else { return }
        if before.isEmpty { OverlayHaptics.press(intensity: hapticIntensity) }
        pressedState.pressed = now
    }

    /// A point normalized in the control's hit frame, in points.
    private func hitPoint(_ point: CGPoint, _ control: ResolvedControl) -> CGPoint {
        CGPoint(x: point.x * control.hitFrame.width, y: point.y * control.hitFrame.height)
    }

    /// L3/R3 from a tap: pressed now, released after `stickClickHold`.
    private func pressStickClick(_ click: OverlayInputID) {
        sink.overlayPress(click)
        OverlayHaptics.press(intensity: hapticIntensity)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stickClickHold) { [sink] in
            sink.overlayRelease(click)
        }
    }

    private func moveStick(_ side: OverlayStickSide, _ point: CGPoint, _ control: ResolvedControl) {
        // `point` is normalized in the hit frame; convert to -1...1 about the centre, clamp to the unit circle.
        let axis = control.control.axis
        var (stickX, stickY) = axis.constrained(x: Float((point.x - 0.5) * 2), y: Float((0.5 - point.y) * 2))
        let magnitude = hypotf(stickX, stickY)
        if magnitude > 1 {
            stickX /= magnitude
            stickY /= magnitude
        }
        if axis == .horizontal {
            let travel = (control.frame.width - OverlayKnobView.diameter(in: control.frame.size, axis: axis)) / 2
            knob.offset = CGSize(width: CGFloat(stickX) * travel, height: 0)
        } else {
            let travel = control.frame.width * Self.knobTravelFraction
            knob.offset = CGSize(width: CGFloat(stickX) * travel, height: -CGFloat(stickY) * travel)
        }
        sink.overlayStick(side, x: stickX, y: stickY)
    }
}

/// Stick art: static ring + a knob that follows `knob.offset` (only this view re-renders on move).
struct OverlayStickArt: View, Equatable {
    let spec: OverlayArtSpec
    let knob: OverlayKnobState
    let axis: OverlayStickAxis

    nonisolated static func == (lhs: OverlayStickArt, rhs: OverlayStickArt) -> Bool {
        lhs.spec == rhs.spec && lhs.axis == rhs.axis
    }

    var body: some View {
        ZStack {
            OverlayControlArt(spec: spec)
            OverlayKnobView(color: spec.color, knob: knob, axis: axis)
        }
    }
}

struct OverlayKnobView: View {
    private static let sizeFraction: CGFloat = 0.45
    /// A horizontal slider's knob fills most of the track's height.
    private static let sliderKnobFraction: CGFloat = 0.8
    private static let opacity: Double = 0.9

    let color: OverlayColor
    let knob: OverlayKnobState
    let axis: OverlayStickAxis

    static func diameter(in size: CGSize, axis: OverlayStickAxis) -> CGFloat {
        axis == .horizontal ? size.height * sliderKnobFraction : size.width * sizeFraction
    }

    var body: some View {
        GeometryReader { geo in
            let diameter = Self.diameter(in: geo.size, axis: axis)
            Circle().fill(Color(color).opacity(Self.opacity))
                .frame(width: diameter, height: axis == .horizontal ? diameter : geo.size.height * Self.sizeFraction)
                .position(x: geo.size.width / 2 + knob.offset.width, y: geo.size.height / 2 + knob.offset.height)
        }
    }
}

public enum OverlayHaptics {
    private static let minIntensity = 0.1

    /// No-op on tvOS, where `UIImpactFeedbackGenerator` is unavailable.
    @MainActor public static func press(intensity: Double) {
        guard intensity > 0 else { return }
#if os(iOS)
        generator.impactOccurred(intensity: min(max(intensity, minIntensity), 1))
#endif
    }

#if os(iOS)
    @MainActor private static let generator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        return generator
    }()
#endif
}
#endif

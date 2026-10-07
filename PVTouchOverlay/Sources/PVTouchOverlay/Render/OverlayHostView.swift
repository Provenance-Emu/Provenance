#if canImport(UIKit)
import SwiftUI
import PVSettings

/// Root overlay view. Lays out on the full-screen canvas; the caller passes a layout
/// already resolved for that canvas.
public struct OverlayHostView: View {
    public let layout: OverlayLayout
    public let binding: SystemOverlayBinding
    public let style: OverlayStyle
    public let globalOpacity: Double
    public let hapticIntensity: Double
    public let sink: any OverlayInputSink
    public let editing: Bool
    /// Held in `@State` so a parent re-render keeps the pressed-set (and so the releases).
    @State private var dispatcher: OverlayHitDispatcher

    public init(layout: OverlayLayout, binding: SystemOverlayBinding, style: OverlayStyle, globalOpacity: Double,
                hapticIntensity: Double, sink: any OverlayInputSink, editing: Bool = false) {
        self.layout = layout
        self.binding = binding
        self.style = style
        self.globalOpacity = globalOpacity
        self.hapticIntensity = hapticIntensity
        self.sink = sink
        self.editing = editing
        _dispatcher = State(initialValue: OverlayHitDispatcher(controls: Self.controls(of: layout), sink: sink))
    }

    private static func controls(of layout: OverlayLayout) -> [OverlayControl] {
        layout.groups.flatMap { $0.group.controls }
    }

    /// Floor so `.opacity(0)` cannot disable hit testing.
    private static let minimumOpacity = 0.05

    private static func isSurface(_ group: ResolvedGroup) -> Bool {
        group.controls.contains { if case .touchSurface = $0.control.kind { return true } else { return false } }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.groups) { group in
                if Self.isSurface(group) {
                    surface(group)
                } else {
                    OverlayGroupView(group: group, palette: binding.palette, style: style, dispatcher: dispatcher,
                                     sink: sink, hapticIntensity: hapticIntensity, editing: editing)
                        .offset(x: group.frame.minX, y: group.frame.minY)
                }
            }
        }
        .opacity(max(globalOpacity, Self.minimumOpacity))
        .allowsHitTesting(!editing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .onChange(of: editing) { _, isEditing in if isEditing { dispatcher.releaseAll() } }
        .onChange(of: layout) { _, newLayout in dispatcher.update(controls: Self.controls(of: newLayout)) }
    }

    @ViewBuilder private func surface(_ group: ResolvedGroup) -> some View {
        if let control = group.controls.first, case .touchSurface(let role) = control.control.kind {
            OverlaySurfaceRepresentable(
                onBegan: { point in sink.overlaySurface(role, normalized: point, phase: .began) },
                onMoved: { point in sink.overlaySurface(role, normalized: point, phase: .moved) },
                onEnded: { sink.overlaySurface(role, normalized: .zero, phase: .ended) })
            .frame(width: control.frame.width, height: control.frame.height)
            .offset(x: control.frame.minX, y: control.frame.minY)
        }
    }
}
#endif

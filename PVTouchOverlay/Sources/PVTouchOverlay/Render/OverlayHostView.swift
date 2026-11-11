#if canImport(UIKit)
import SwiftUI
import PVSettings
import SkinKit2Core
import UIKit

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
    private let canvas: OverlayCanvas?
    private let format2Sources: URL?
    /// Held in `@State` so a parent re-render keeps the pressed-set (and so the releases).
    @State private var dispatcher: OverlayHitDispatcher
    @Default(.arcadeMultiButtonTouch) private var arcadeMultiButtonTouch

    public init(layout: OverlayLayout, binding: SystemOverlayBinding, style: OverlayStyle, globalOpacity: Double,
                hapticIntensity: Double, sink: any OverlayInputSink, editing: Bool = false,
                canvas: OverlayCanvas? = nil, format2Sources: URL? = nil) {
        self.layout = layout
        self.binding = binding
        self.style = style
        self.globalOpacity = globalOpacity
        self.hapticIntensity = hapticIntensity
        self.sink = sink
        self.editing = editing
        self.canvas = canvas
        self.format2Sources = format2Sources
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
        let artwork = format2Artwork
        ZStack(alignment: .topLeading) {
            ForEach(layout.groups) { group in
                if Self.isSurface(group) {
                    surface(group)
                } else {
                    OverlayGroupView(group: group, palette: binding.palette, style: style, dispatcher: dispatcher,
                                     sink: sink, hapticIntensity: hapticIntensity, editing: editing,
                                     artwork: artwork, multiButton: multiButton(for: group))
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

    private var format2Artwork: OverlayFormat2Artwork? {
        guard let canvas, let format2Sources, canvas.size.width > 0, canvas.size.height > 0,
              let document = OverlayFormat2Sources.document(in: format2Sources, pad: layout.padKind, binding: binding, style: style) else { return nil }
        #if os(tvOS)
        let device = Skin2Device.tv
        #else
        let device: Skin2Device = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
        let safe = canvas.safeArea
        let edgeToEdge = safe.bottom > 0 || safe.left > 0 || safe.right > 0
        let environment = Skin2Environment(size: .init(width: canvas.size.width, height: canvas.size.height),
                                           safeArea: .init(top: safe.top, left: safe.left, bottom: safe.bottom, right: safe.right),
                                           orientation: layout.orientation == .portrait ? .portrait : .landscape,
                                           device: device, displayType: device == .iphone && edgeToEdge ? .edgeToEdge : .standard)
        return OverlayFormat2Artwork(document: document, layout: layout, environment: environment)
    }

    private func multiButton(for group: ResolvedGroup) -> Bool {
        OverlayMultiButtonTouch.applies(toGroup: group.id, familyID: binding.family(for: layout.padKind.subtype).id,
                                        arcadeEnabled: arcadeMultiButtonTouch)
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

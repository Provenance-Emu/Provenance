//
//  ProgrammaticOverlayView.swift
//  PVUIBase
//
//  Mounts the PVTouchOverlay controller in place of the generated default skin.
//

#if !os(tvOS)
import SwiftUI
import Defaults
import PVEmulatorCore
import PVSettings
import PVSystems
import PVTouchOverlay

/// Shows `OverlayHostView` for a bound system, publishes the game viewport through
/// `ViewportLayoutProviderBridge` (single screen) or `onScreenFrames` (every layout,
/// which the emulator view controller uses for the DS split), and hosts the editor.
///
/// Lays out on the full container: `EmulatorWrapperView` ignores the safe area, so the
/// geometry size is the whole screen and its insets are the device safe area, the same
/// coordinate space the default skin's viewport uses.
struct ProgrammaticOverlayView: View {
    let systemId: SystemIdentifier
    let binding: SystemOverlayBinding
    let coreInstance: PVEmulatorCore
    let inputHandler: DeltaSkinInputHandler
    let gameMD5: String?
    /// Called with the resolved screen frames (1 or 2) whenever they change, and with
    /// an empty array when the overlay goes away.
    let onScreenFrames: ([CGRect]) -> Void

    @ObservedObject private var store = OverlayLayoutStore.shared
    @Default(.overlayStyle) private var style
    @Default(.controllerOpacity) private var globalOpacity
    @Default(.overlayHapticIntensity) private var hapticIntensity
    @Default(.buttonVibration) private var hapticsOn
    @State private var padKind: OverlayPadKind
    @State private var sink: OverlayInputSinkAdapter?
    @State private var viewport = OverlayViewportPublisher()
    @State private var editController: OverlayEditController?
    /// Bumped when the core reports its real geometry, so `body` re-reads the game aspect.
    @State private var coreAVInfoRevision = 0

    /// How long an empty-space press must last to open the editor.
    private static let editHoldDuration: Double = 0.5
    /// Accepted game aspect ratios; anything else is a not-yet-booted core's fallback.
    private static let plausibleAspect: ClosedRange<CGFloat> = 0.5...2.5
    private static let fallbackAspect: CGFloat = 4.0 / 3.0

    init(systemId: SystemIdentifier, binding: SystemOverlayBinding, coreInstance: PVEmulatorCore,
         inputHandler: DeltaSkinInputHandler, gameMD5: String?, padKind: OverlayPadKind,
         onScreenFrames: @escaping ([CGRect]) -> Void) {
        self.systemId = systemId
        self.binding = binding
        self.coreInstance = coreInstance
        self.inputHandler = inputHandler
        self.gameMD5 = gameMD5
        self.onScreenFrames = onScreenFrames
        _padKind = State(initialValue: padKind)
    }

    var body: some View {
        GeometryReader { geo in
            let canvas = Self.canvas(for: geo)
            let template = binding.template(padKind: padKind, orientation: canvas.orientation)
            let layout = resolve(template, on: canvas)
            ZStack(alignment: .topLeading) {
                editHoldArea(canvas: canvas, screens: layout.screenFrames) {
                    beginEditing(template: template, canvas: canvas)
                }
                if let sink {
                    OverlayHostView(layout: layout, binding: binding, style: style, globalOpacity: globalOpacity,
                                    hapticIntensity: hapticsOn ? hapticIntensity : 0, sink: sink,
                                    editing: editController != nil)
                }
                if let editController {
                    OverlayEditorView(controller: editController, layout: layout, binding: binding,
                                      style: style) { _ in
                        self.editController = nil
                    }
                }
            }
            .frame(width: canvas.size.width, height: canvas.size.height, alignment: .topLeading)
            .onAppear {
                if sink == nil { sink = OverlayInputSinkAdapter(handler: inputHandler) }
                viewport.attach(to: coreInstance)
                publish(layout.screenFrames)
            }
            .onChange(of: layout.screenFrames) { _, frames in publish(frames) }
            .onChange(of: editController != nil) { _, editing in postEditing(editing) }
            .onReceive(NotificationCenter.default.publisher(for: .overlayEditLayoutRequested)) { _ in
                beginEditing(template: template, canvas: canvas)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .thinLibretroCoreAVInfoDidUpdate)) { _ in
            coreAVInfoRevision &+= 1
        }
        // The controller cleared its frame (rotation): re-send the current frames even
        // though they did not change. (Scaling-mode changes are re-applied by the VC.)
        .onReceive(NotificationCenter.default.publisher(for: .deltaSkinForceRecalculate)) { _ in
            republish()
        }
        .onDisappear {
            if let editController {
                editController.cancel()
                self.editController = nil
                postEditing(false)
            }
            viewport.detach(from: coreInstance)
            onScreenFrames([])
        }
    }

    /// Clear layer under the controls that opens the editor on a long press. The game
    /// screens are cut out of its hit shape so touches there still reach the game view.
    private func editHoldArea(canvas: OverlayCanvas, screens: [CGRect],
                              onHold: @escaping () -> Void) -> some View {
        var shape = Path(canvas.bounds)
        for screen in screens { shape.addRect(screen) }
        return Color.clear
            .frame(width: canvas.size.width, height: canvas.size.height)
            .contentShape(shape, eoFill: true)
            .onLongPressGesture(minimumDuration: Self.editHoldDuration, perform: onHold)
    }

    private static func canvas(for geo: GeometryProxy) -> OverlayCanvas {
        let insets = geo.safeAreaInsets
        return OverlayCanvas(size: geo.size,
                             safeArea: OverlayInsets(top: insets.top, left: insets.leading,
                                                     bottom: insets.bottom, right: insets.trailing))
    }

    private func resolve(_ template: OverlayTemplate, on canvas: OverlayCanvas) -> OverlayLayout {
        _ = store.revision // re-resolve when the stored layout changes
        _ = coreAVInfoRevision
        let key = padKind.storageKey(for: canvas.orientation)
        return OverlayLayoutEngine.resolve(template: template, canvas: canvas,
                                           overrides: store.overrides(for: key, gameMD5: gameMD5),
                                           gameAspect: gameAspect())
    }

    private func gameAspect() -> CGFloat {
        let size = coreInstance.aspectSize
        guard size.width > 0, size.height > 0 else { return Self.fallbackAspect }
        let ratio = size.width / size.height
        return Self.plausibleAspect.contains(ratio) ? ratio : Self.fallbackAspect
    }

    private func beginEditing(template: OverlayTemplate, canvas: OverlayCanvas) {
        guard editController == nil else { return }
        var defaults: [String: OverlayEditController.GroupDefaults] = [:]
        for group in template.groups where defaults[group.id] == nil {
            defaults[group.id] = (scale: CGSize(width: group.scale, height: group.scale), opacity: group.opacity)
        }
        editController = OverlayEditController(store: store, key: padKind.storageKey(for: canvas.orientation),
                                               gameMD5: gameMD5, canvas: canvas, groupDefaults: defaults)
    }

    /// The editor pauses the core while it is open (the VC owns the pause).
    private func postEditing(_ editing: Bool) {
        NotificationCenter.default.post(name: .overlayEditingDidChange, object: nil,
                                        userInfo: OverlayNotificationPayload.userInfo(editing: editing))
    }

    private func republish() {
        publish(viewport.lastFrames, force: true)
    }

    private func publish(_ frames: [CGRect], force: Bool = false) {
        guard force || frames != viewport.lastFrames, let first = frames.first, first.width > 0, first.height > 0 else {
            return
        }
        viewport.lastFrames = frames
        // A DS split is applied by the view controller from `onScreenFrames`; sending the
        // top screen through the single-viewport path would resize the Metal view over it.
        if frames.count == 1 {
            viewport.bridge?.notifyFrameUpdated(first)
        }
        onScreenFrames(frames)
    }
}

/// Reference box for the viewport bridge, so the bridge's frame closure reads the
/// latest frames instead of a copy captured with the view value.
final class OverlayViewportPublisher {
    var lastFrames: [CGRect] = []
    private(set) var bridge: ViewportLayoutProviderBridge?

    func attach(to core: PVEmulatorCore) {
        guard bridge == nil else { return }
        bridge = ViewportLayoutProviderBridge(core: core, calculateFrame: { [weak self] _, _, _ in
            guard let frames = self?.lastFrames, frames.count == 1 else { return nil }
            return frames.first
        })
    }

    func detach(from core: PVEmulatorCore) {
        if core.viewportLayoutProvider === bridge { core.viewportLayoutProvider = nil }
        bridge = nil
        lastFrames = []
    }
}
#endif

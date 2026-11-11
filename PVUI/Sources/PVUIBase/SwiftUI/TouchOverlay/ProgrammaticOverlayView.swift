//
//  ProgrammaticOverlayView.swift
//  PVUIBase
//
//  Mounts the PVTouchOverlay controller in place of the generated default skin.
//

#if !os(tvOS)
import SwiftUI
import Defaults
import PVCoreBridge
import PVEmulatorCore
import PVLogging
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
    /// Whether the keypad group is shown. The editor always shows it so it can be moved.
    @State private var keypadShown = false
    @State private var switchPositionIndexes: [String: Int] = [:]
    /// Bumped when the core reports its real geometry, so `body` re-reads the game aspect.
    @State private var coreAVInfoRevision = 0

    private static let fallbackAspect: CGFloat = 4.0 / 3.0
    private static let format2Sources = Bundle.module.url(forResource: "Programmatic", withExtension: nil, subdirectory: "DefaultSkins")
    /// Per-game or per-system controller variant choices changed.
    private static let variantSettingsChanged = Defaults
        .publisher(keys: .controllerLayoutVariantsByGame, .controllerLayoutVariantsBySystem, options: [])
        .receive(on: DispatchQueue.main)

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
            let layout = resolve(template, on: canvas, editing: editController != nil)
            // The editor opens only on request (pause menu "Edit Layout" or the view
            // controller's three-finger hold), never from a press on the controls' area.
            ZStack(alignment: .topLeading) {
                if let sink {
                    OverlayHostView(layout: layout, binding: binding, style: style, globalOpacity: globalOpacity,
                                    hapticIntensity: hapticsOn ? hapticIntensity : 0, sink: sink,
                                    editing: editController != nil, canvas: canvas, format2Sources: Self.format2Sources)
                }
                if let editController {
                    OverlayEditorView(controller: editController, layout: layout, binding: binding,
                                      style: style, globalOpacity: globalOpacity,
                                      systemName: systemId.systemName, format2Sources: Self.format2Sources,
                                      askSaveScope: { thisGame, allGames in
                                          PVAlertCenter.shared.present(PVAlert(
                                              title: "Save layout for:",
                                              style: .actionSheet,
                                              actions: [
                                                  PVAlertAction("This game", handler: thisGame),
                                                  PVAlertAction("All \(systemId.systemName) games", handler: allGames),
                                                  .cancel()
                                              ]
                                          ))
                                      }) { _ in
                        self.editController = nil
                    }
                }
            }
            .frame(width: canvas.size.width, height: canvas.size.height, alignment: .topLeading)
            .onAppear {
                if sink == nil {
                    let adapter = OverlayInputSinkAdapter(handler: inputHandler)
                    adapter.onKeypadToggle = { keypadShown.toggle() }
                    sink = adapter
                }
                viewport.attach(to: coreInstance)
                Self.log(layout, on: canvas, reason: "appear")
                publish(layout.screenFrames)
                Self.postControlFrames(Self.controlFrames(of: layout))
            }
            .onChange(of: layout.screenFrames) { _, frames in publish(frames) }
            .onChange(of: Self.controlFrames(of: layout)) { _, frames in Self.postControlFrames(frames) }
            // The editor edits one orientation's layout against a fixed canvas; on rotation it
            // ends (edits stay saved) and the player re-enters it in the new orientation.
            .onChange(of: canvas.size) { _, _ in
                Self.log(layout, on: canvas, reason: "canvas")
                endEditingForCanvasChange()
            }
            .onChange(of: editController != nil) { _, editing in
                postEditing(editing)
                if !editing { refreshPadKind() } // catch up on a change made while editing
            }
            .onReceive(NotificationCenter.default.publisher(for: .overlayEditLayoutRequested)) { _ in
                beginEditing(template: template, canvas: canvas)
            }
            .onReceive(NotificationCenter.default.publisher(for: .deltaSkinForceRecalculate)) { _ in
                let freshLayout = resolve(template, on: Self.canvas(for: geo), editing: editController != nil)
                publish(freshLayout.screenFrames, force: true)
                Self.postControlFrames(Self.controlFrames(of: freshLayout))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .thinLibretroCoreAVInfoDidUpdate)) { _ in
            coreAVInfoRevision &+= 1
            // The thin core declares its port devices at load, after the overlay mounted.
            refreshPadKind()
        }
        .onReceive(NotificationCenter.default.publisher(for: .controllerLayoutVariantDidChange)) { notification in
            guard notification.object as? PVEmulatorCore === coreInstance else { return }
            refreshPadKind()
        }
        .onReceive(inputHandler.$hardwareSwitchPositionIndexes) { positions in
            switchPositionIndexes = positions
        }
        // Pause-menu and Settings choices, including ones the core could not apply.
        .onReceive(Self.variantSettingsChanged) { _ in
            refreshPadKind()
        }
        .onDisappear {
            if let editController {
                editController.cancel()
                self.editController = nil
                postEditing(false)
            }
            viewport.detach(from: coreInstance)
            onScreenFrames([])
            Self.postControlFrames([])
        }
    }

    /// Where every group landed, so a device log shows controls resolved off screen or an
    /// unsettled canvas (no safe area yet) behind a missing pad or a misplaced picture.
    private static func log(_ layout: OverlayLayout, on canvas: OverlayCanvas, reason: String) {
        let groups = layout.groups.map { "\($0.group.id)=\($0.frame.integral)" }.joined(separator: " ")
        ILOG("Overlay[\(reason)]: \(layout.orientation) canvas=\(canvas.size) safe=\(canvas.safeArea) "
             + "screens=\(layout.screenFrames) groups: \(groups)")
    }

    /// `EmulatorWrapperView` ignores the safe area for the whole emulator, so `geo` reports none and the
    /// system row landed in the home-indicator strip (and the pad under the Dynamic Island in landscape),
    /// where a touch goes home or to Siri instead. The window's insets keep the controls clear of both.
    private static func canvas(for geo: GeometryProxy) -> OverlayCanvas {
        let insets = geo.safeAreaInsets
        let window = windowSafeAreaInsets()
        return OverlayCanvas(size: geo.size,
                             safeArea: OverlayInsets(top: max(insets.top, window.top),
                                                     left: max(insets.leading, window.left),
                                                     bottom: max(insets.bottom, window.bottom),
                                                     right: max(insets.trailing, window.right)))
    }

    private static func windowSafeAreaInsets() -> UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.keyWindow?.safeAreaInsets ?? .zero
    }

    private func resolve(_ template: OverlayTemplate, on canvas: OverlayCanvas, editing: Bool) -> OverlayLayout {
        _ = store.revision // re-resolve when the stored layout changes
        _ = coreAVInfoRevision
        let key = padKind.storageKey(for: template.orientation)
        let aspect = gameAspect()
        // A portrait phone usually has vertical room for controls below the game.
        // Tablets, landscape phones and tall games use the full canvas under the overlay.
        let idiom = UIDevice.current.userInterfaceIdiom
        let reserveSpace = idiom == .phone && canvas.orientation == .portrait && aspect >= 1
        let switchLabels = (systemId.hardwareSwitches ?? []).reduce(into: [String: String]()) { labels, descriptor in
            let index = switchPositionIndexes[descriptor.id] ?? descriptor.initialPositionIndex
            if descriptor.positionList.indices.contains(index) {
                labels[descriptor.id] = descriptor.positionList[index].label
            }
        }
        return OverlayLayoutEngine.resolve(template: template, canvas: canvas,
                                           overrides: store.overrides(for: key, gameMD5: gameMD5),
                                           gameAspect: aspect,
                                           shownToggles: editing || keypadShown ? [.keypad] : [],
                                           reservesControlSpace: reserveSpace, arrangesConsoleRow: idiom == .pad,
                                           switchPositionLabels: switchLabels)
    }

    private func gameAspect() -> CGFloat {
        ScalingModeLayout.displayAspect(reported: coreInstance.aspectSize,
                                        fallback: coreInstance.screenRect.size) ?? Self.fallbackAspect
    }

    /// Not while the editor is open: it keeps the storage key of the layout it is editing.
    private func refreshPadKind() {
        guard editController == nil else { return }
        let resolved = OverlayPadKindResolver.padKind(for: systemId,
                                                      variantProvider: coreInstance as? ConsoleVariantConfigurable,
                                                      gameMD5: gameMD5 ?? "")
        if resolved != padKind { padKind = resolved }
    }

    private func beginEditing(template: OverlayTemplate, canvas: OverlayCanvas) {
        guard editController == nil else { return }
        var defaults: [String: OverlayEditController.GroupDefaults] = [:]
        for group in template.groups where defaults[group.id] == nil {
            defaults[group.id] = (scale: CGSize(width: group.scale, height: group.scale), opacity: group.opacity)
        }
        editController = OverlayEditController(store: store, key: padKind.storageKey(for: template.orientation),
                                               gameMD5: gameMD5, canvas: canvas, groupDefaults: defaults)
    }

    private func endEditingForCanvasChange() {
        guard let editController else { return }
        editController.done()
        self.editController = nil
    }

    /// Every drawn control except touch surfaces, which sit over the game picture like the screen.
    static func controlFrames(of layout: OverlayLayout) -> [CGRect] {
        layout.groups.flatMap(\.controls).compactMap { resolved in
            if case .touchSurface = resolved.control.kind { return nil }
            return resolved.frame
        }
    }

    private static func postControlFrames(_ frames: [CGRect]) {
        NotificationCenter.default.post(name: .overlayControlFramesDidChange, object: nil,
                                        userInfo: OverlayNotificationPayload.userInfo(frames: frames))
    }

    /// The editor pauses the core while it is open (the VC owns the pause).
    private func postEditing(_ editing: Bool) {
        NotificationCenter.default.post(name: .overlayEditingDidChange, object: nil,
                                        userInfo: OverlayNotificationPayload.userInfo(editing: editing))
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

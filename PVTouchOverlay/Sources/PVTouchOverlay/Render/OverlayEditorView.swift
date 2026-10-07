#if canImport(UIKit)
import SwiftUI
import PVSettings

/// Edit chrome drawn over a non-interactive `OverlayHostView`. Each group gets a dashed
/// frame, a drag gesture, a corner resize handle and tap-to-select; a floating inspector
/// edits the selection; the toolbar offers Undo/Redo/Reset/Cancel/Done. Done on a per-game
/// session asks whether the layout is for this game or every game of the system (spec §7.2).
public struct OverlayEditorView: View {
    @Bindable var controller: OverlayEditController
    public let layout: OverlayLayout
    public let binding: SystemOverlayBinding
    public let style: OverlayStyle
    /// The player's controller opacity, so the pad is previewed as it will look in play.
    public let globalOpacity: Double
    /// Display name of the system, for the "All <system> games" save choice.
    public let systemName: String
    public let onFinish: (_ saved: Bool) -> Void
    @State private var choosingSaveScope = false
    @State private var dragStartCenter: CGPoint?
    @State private var pinchStart: CGFloat = 1
    @State private var lastControlTranslation: CGSize = .zero
    @State private var lastHandleWidth: CGFloat = 0

    public init(controller: OverlayEditController, layout: OverlayLayout, binding: SystemOverlayBinding,
                style: OverlayStyle, globalOpacity: Double, systemName: String,
                onFinish: @escaping (_ saved: Bool) -> Void) {
        self.controller = controller
        self.layout = layout
        self.binding = binding
        self.style = style
        self.globalOpacity = globalOpacity
        self.systemName = systemName
        self.onFinish = onFinish
    }

    public var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = controller.revision // read so edits re-render this view
        ZStack(alignment: .topLeading) {
            OverlayHostView(layout: layout, binding: binding, style: style, globalOpacity: globalOpacity,
                            hapticIntensity: 0, sink: OverlayNullSink.shared, editing: true)
            ForEach(layout.groups) { group in groupChrome(group) }
            VStack {
                toolbar
                Spacer()
                if controller.selectedGroupID != nil { inspector }
            }
            .padding()
            // The editor ignores the safe area (it draws on the canvas); keep its chrome out of the notch.
            .padding(EdgeInsets(top: safeArea.top, leading: safeArea.left,
                                bottom: safeArea.bottom, trailing: safeArea.right))
        }
        .ignoresSafeArea()
    }

    private var safeArea: OverlayInsets { controller.canvas.safeArea }

    @ViewBuilder private func groupChrome(_ group: ResolvedGroup) -> some View {
        let selected = controller.selectedGroupID == group.id
        Group {
            frameChrome(group, selected: selected)
            resizeHandle(group)
            detachedChrome(group)
        }
    }

    private func frameChrome(_ group: ResolvedGroup, selected: Bool) -> some View {
        let chrome = Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: [6, 4]))
            .foregroundStyle(selected ? Color.yellow : Color.white.opacity(0.7))
            .frame(width: group.frame.width, height: group.frame.height)
            .offset(x: group.frame.minX, y: group.frame.minY)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { controller.resetGroup(group.id) }
            .onTapGesture { controller.selectedGroupID = group.id; controller.selectedControlID = nil }
        #if !os(tvOS)
        return chrome
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { value in
                    controller.beginInteraction()
                    let start = dragStartCenter ?? CGPoint(x: group.frame.midX, y: group.frame.midY)
                    dragStartCenter = start
                    controller.moveGroup(group.id, to: CGPoint(x: start.x + value.translation.width,
                                                               y: start.y + value.translation.height))
                }
                .onEnded { _ in dragStartCenter = nil; controller.endInteraction() })
            .simultaneousGesture(MagnificationGesture()
                .onChanged { magnification in
                    controller.beginInteraction()
                    controller.scaleGroup(group.id, by: magnification / pinchStart)
                    pinchStart = magnification
                }
                .onEnded { _ in pinchStart = 1; controller.endInteraction() })
        #else
        return chrome
        #endif
    }

    @ViewBuilder private func resizeHandle(_ group: ResolvedGroup) -> some View {
        let handle = Circle().fill(Color.yellow).frame(width: 22, height: 22)
            .offset(x: group.frame.maxX - 11, y: group.frame.maxY - 11)
        #if !os(tvOS)
        handle.gesture(DragGesture()
            .onChanged { value in
                controller.beginInteraction()
                let delta = value.translation.width - lastHandleWidth
                lastHandleWidth = value.translation.width
                controller.scaleGroup(group.id, by: 1 + delta / max(group.frame.width, 1))
            }
            .onEnded { _ in lastHandleWidth = 0; controller.endInteraction() })
        #else
        handle
        #endif
    }

    @ViewBuilder private func detachedChrome(_ group: ResolvedGroup) -> some View {
        ForEach(group.controls.filter { controller.detached.contains("\(group.id)/\($0.id)") }) { resolved in
            let chrome = Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.cyan)
                .frame(width: resolved.frame.width, height: resolved.frame.height)
                .offset(x: resolved.frame.minX, y: resolved.frame.minY)
                .contentShape(Rectangle())
            #if !os(tvOS)
            chrome.gesture(DragGesture(minimumDistance: 2)
                .onChanged { value in
                    controller.beginInteraction()
                    let delta = CGPoint(x: value.translation.width - lastControlTranslation.width,
                                        y: value.translation.height - lastControlTranslation.height)
                    lastControlTranslation = value.translation
                    controller.moveControl(groupID: group.id, controlID: resolved.id, by: delta)
                }
                .onEnded { _ in lastControlTranslation = .zero; controller.endInteraction() })
            #else
            chrome
            #endif
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Button("Undo") { controller.undo() }.disabled(!controller.canUndo)
            Button("Redo") { controller.redo() }.disabled(!controller.canRedo)
            Button("Reset Pad") { controller.resetAll() }
            Spacer()
            Button("Cancel") { controller.cancel(); onFinish(false) }
            Button("Done") {
                if controller.canSaveForAllGames {
                    choosingSaveScope = true
                } else {
                    controller.done()
                    onFinish(true)
                }
            }
            .bold()
            .confirmationDialog("Save layout for:", isPresented: $choosingSaveScope, titleVisibility: .visible) {
                Button("This game") { controller.done(); onFinish(true) }
                Button("All \(systemName) games") { controller.doneForAllGames(); onFinish(true) }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var inspector: some View {
        let groupID = controller.selectedGroupID ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(groupID).font(.headline)
            #if !os(tvOS)
            HStack {
                Text("Opacity")
                Slider(value: Binding(get: { Double(controller.effectiveOpacity(groupID)) },
                                      set: { controller.setOpacity(groupID, CGFloat($0)) }),
                       in: 0.1...1, onEditingChanged: editing)
            }
            HStack {
                Text("Scale")
                Slider(value: Binding(get: { Double(controller.effectiveScale(groupID).width) },
                                      set: { controller.setScale(groupID, CGFloat($0)) }),
                       in: 0.5...2, onEditingChanged: editing)
            }
            #endif
            if let group = layout.groups.first(where: { $0.id == groupID }), group.controls.count > 1 {
                ForEach(group.controls) { resolved in
                    detachToggle(groupID: groupID, resolved: resolved)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func editing(_ isEditing: Bool) {
        if isEditing { controller.beginInteraction() } else { controller.endInteraction() }
    }

    private func detachToggle(groupID: String, resolved: ResolvedControl) -> some View {
        let detachKey = "\(groupID)/\(resolved.id)"
        return Toggle("Detach \(resolved.control.label ?? resolved.id)", isOn: Binding(
            get: { controller.detached.contains(detachKey) },
            set: { isOn in
                if isOn {
                    controller.detachControl(groupID: groupID, controlID: resolved.id)
                } else {
                    controller.reattachControl(groupID: groupID, controlID: resolved.id)
                }
            }))
    }
}

/// Sink used while editing so no input reaches the core.
public final class OverlayNullSink: OverlayInputSink, Sendable {
    public static let shared = OverlayNullSink()
    public func overlayPress(_ id: OverlayInputID) {}
    public func overlayRelease(_ id: OverlayInputID) {}
    public func overlayStick(_ side: OverlayStickSide, x horizontal: Float, y vertical: Float) {}
    public func overlayAnalogTrigger(_ id: OverlayInputID, value: Float) {}
    public func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase) {}
    public func overlayAction(_ action: OverlayAction) {}
    public func overlayHardwareSwitch(descriptorID: String, isOn: Bool) {}
}
#endif

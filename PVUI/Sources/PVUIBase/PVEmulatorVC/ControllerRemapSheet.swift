//
//  ControllerRemapSheet.swift
//  PVUIBase
//
//  Presents the pause menu's "Remap Controller" screen (registered by PVSwiftUI)
//  from either pause menu style.
//

import SwiftUI
import GameController

/// The controller a "Remap Controller" presentation edits.
struct ControllerRemapTarget: Identifiable {
    let id = UUID()
    let controller: GCController
}

private struct ControllerRemapSheetModifier: ViewModifier {
    @Binding var target: ControllerRemapTarget?
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        // The pause menu stays up underneath, so the core stays paused while remapping.
        // tvOS uses a full-screen cover, as for App Settings: a sheet renders narrow there.
        #if os(tvOS)
        content.fullScreenCover(item: $target, onDismiss: onDismiss, content: remapView)
        #else
        content.sheet(item: $target, onDismiss: onDismiss, content: remapView)
        #endif
    }

    @ViewBuilder
    private func remapView(_ target: ControllerRemapTarget) -> some View {
        if let view = PauseMenuViewRegistry.controllerRemapView(for: target.controller, dismissAction: {
            self.target = nil
        }) {
            view
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Shows the controller remapping screen while `target` is set; `onDismiss` runs after it closes.
    func controllerRemapSheet(target: Binding<ControllerRemapTarget?>, onDismiss: @escaping () -> Void) -> some View {
        modifier(ControllerRemapSheetModifier(target: target, onDismiss: onDismiss))
    }
}

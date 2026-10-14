//
//  InGameControllerRemapView.swift
//  PVSwiftUI
//
//  Pause menu "Remap Controller": the Settings button remapping screen for one
//  controller, presented over a running (paused) game.
//

import SwiftUI
import GameController

/// `ButtonRemappingView` for one controller in its own navigation stack (it pushes
/// the profiles screen), with a "Done" that hands control back to the pause menu.
/// Registered with `PauseMenuViewRegistry` at launch.
struct InGameControllerRemapView: View {
    let controller: GCController
    let dismissAction: (() -> Void)?

    var body: some View {
        NavigationStack {
            ButtonRemappingView(controller: controller, startInPressMode: true)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismissAction?() }
                    }
                }
        }
        #if os(tvOS)
        .settingsSheetDetachedFromSubpageDepth()
        #endif
    }
}

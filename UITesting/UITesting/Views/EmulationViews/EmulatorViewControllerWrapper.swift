//  EmulatorViewControllerWrapper.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVUIBase

/// SwiftUI wrapper for PVEmulatorViewController
struct EmulatorViewControllerWrapper: UIViewControllerRepresentable {
    let game: PVGame
    let coreInstance: PVEmulatorCore

    func makeUIViewController(context: Context) -> PVEmulatorViewController {
        let emulatorViewController = PVEmulatorViewController(game: game, core: coreInstance)
        return emulatorViewController
    }

    func updateUIViewController(_ uiViewController: PVEmulatorViewController, context: Context) {
        // Update the view controller if needed
    }
}

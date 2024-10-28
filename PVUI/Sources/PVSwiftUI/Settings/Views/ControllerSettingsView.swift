//
//  ControllerSettingsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVUIBase
import PVUI_IOS
import PVUIKit

struct ControllerSettingsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PVControllerSelectionViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "PVControllerSelectionViewController") as! PVControllerSelectionViewController
    }

    func updateUIViewController(_ uiViewController: PVControllerSelectionViewController, context: Context) {
        // Update the view controller if needed
    }
}

//
//  SystemSettingsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI

struct SystemSettingsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SystemsSettingsTableViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "systemSettingsTableViewController") as! SystemsSettingsTableViewController
    }

    func updateUIViewController(_ uiViewController: SystemsSettingsTableViewController, context: Context) {
        // Update the view controller if needed
    }
}

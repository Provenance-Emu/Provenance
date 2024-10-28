//
//  CoreOptionsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI

struct CoreOptionsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CoreOptionsTableViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "coreOptionsTablewView") as! CoreOptionsTableViewController
    }

    func updateUIViewController(_ uiViewController: CoreOptionsTableViewController, context: Context) {
        // Update the view controller if needed
    }
}

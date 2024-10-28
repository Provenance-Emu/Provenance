//
//  LicensesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI

struct LicensesView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PVLicensesViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        let licensesViewController = storyboard.instantiateViewController(withIdentifier: "licensesViewController") as! PVLicensesViewController
        licensesViewController.title = "Licenses"
        return licensesViewController
    }

    func updateUIViewController(_ uiViewController: PVLicensesViewController, context: Context) {
        // Update the view controller if needed
    }
}

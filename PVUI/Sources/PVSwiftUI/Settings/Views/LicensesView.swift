//
//  LicensesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
#if canImport(PVUI_IOS)
import PVUI_IOS
#elseif canImport(PVUI_AppKit)
import PVUI_AppKit
#elseif canImport(PVUI_TV)
import PVUI_TV
#endif

struct LicensesView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PVLicensesViewController {
#if canImport(PVUI_IOS)
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        let licensesViewController = storyboard.instantiateViewController(withIdentifier: "licensesViewController") as! PVLicensesViewController
        licensesViewController.title = "Licenses"
        return licensesViewController
#elseif canImport(PVUI_TV)
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_TV.BundleLoader.bundle)
        let licensesViewController = storyboard.instantiateViewController(withIdentifier: "licensesViewController") as! PVLicensesViewController
        licensesViewController.title = "Licenses"
        return licensesViewController
#endif

    }

    func updateUIViewController(_ uiViewController: PVLicensesViewController, context: Context) {
        // Update the view controller if needed
    }
}

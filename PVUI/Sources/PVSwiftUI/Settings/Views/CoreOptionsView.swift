//
//  CoreOptionsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

#if canImport(PVUI_IOS)
import PVUI_IOS
#elseif canImport(PVUI_AppKit)
import PVUI_AppKit
#elseif canImport(PVUI_TV)
import PVUI_TV
#endif
import SwiftUI

struct CoreOptionsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CoreOptionsTableViewController {
#if canImport(PVUI_IOS)
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "coreOptionsTablewView") as! CoreOptionsTableViewController
#elseif canImport(PVUI_TV)
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_TV.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "coreOptionsTablewView") as! CoreOptionsTableViewController
#endif
    }

    func updateUIViewController(_ uiViewController: CoreOptionsTableViewController, context: Context) {
        // Update the view controller if needed
    }
}

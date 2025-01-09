//
//  ICadeControllerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVUIBase
#if canImport(PVUI_IOS)
import PVUI_IOS
#endif
#if canImport(PVUI_TV)
import PVUI_TV
#endif
import PVUIKit

struct ICadeControllerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PViCadeControllerViewController {
#if canImport(PVUI_IOS)
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "PViCadeControllerViewController") as! PViCadeControllerViewController
#elseif canImport(PVUI_TV)
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_TV.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "PViCadeControllerViewController") as! PViCadeControllerViewController
#endif
    }

    func updateUIViewController(_ uiViewController: PViCadeControllerViewController, context: Context) {
        // Update the view controller if needed
    }
}

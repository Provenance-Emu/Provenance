//
//  ICadeControllerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVUIBase
import PVUI_IOS
import PVUIKit

struct ICadeControllerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PViCadeControllerViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "PViCadeControllerViewController") as! PViCadeControllerViewController
    }

    func updateUIViewController(_ uiViewController: PViCadeControllerViewController, context: Context) {
        // Update the view controller if needed
    }
}

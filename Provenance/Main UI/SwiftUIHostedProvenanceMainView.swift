//
//  SwiftUIHostedProvenanceMainView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import Foundation
import PVLogging

struct SwiftUIHostedProvenanceMainView: UIViewControllerRepresentable {
    let appDelegate: PVAppDelegate

    init(appDelegate: PVAppDelegate) {
        ILOG("MainView: Using SwiftUI interface")
        self.appDelegate = appDelegate
    }

    func makeUIViewController(context: Context) -> UIViewController {
        ILOG("SwiftUIHostedProvenanceMainView: Making UIViewController")
        return appDelegate.setupSwiftUIInterface()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        ILOG("SwiftUIHostedProvenanceMainView: Updating UIViewController")
    }
}

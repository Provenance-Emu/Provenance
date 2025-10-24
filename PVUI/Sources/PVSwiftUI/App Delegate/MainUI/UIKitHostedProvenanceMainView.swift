//
//  UIKitHostedProvenanceMainView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import Foundation
import PVLogging

public struct UIKitHostedProvenanceMainView: UIViewControllerRepresentable {
    public let appDelegate: PVAppDelegate

    public init(appDelegate: PVAppDelegate) {
        ILOG("MainView: Using UIKit interface")
        self.appDelegate = appDelegate
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        ILOG("UIKitHostedProvenanceMainView: Making UIViewController")
        return appDelegate.setupUIKitInterface()
    }

    public  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        ILOG("UIKitHostedProvenanceMainView: Updating UIViewController")
    }
}

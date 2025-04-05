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

public struct SwiftUIHostedProvenanceMainView: UIViewControllerRepresentable {
    /// Use EnvironmentObject for app delegate
    @EnvironmentObject private var appDelegate: PVAppDelegate

    public init() { }

    public func makeUIViewController(context: Context) -> UIViewController {
        ILOG("SwiftUIHostedProvenanceMainView: Making UIViewController")
        return appDelegate.setupSwiftUIInterface()
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        ILOG("SwiftUIHostedProvenanceMainView: Updating UIViewController")
    }
}

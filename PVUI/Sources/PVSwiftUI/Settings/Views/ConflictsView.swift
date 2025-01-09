//
//  ConflictsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import UIKit

struct ConflictsView: UIViewControllerRepresentable {
    @EnvironmentObject var viewModel: PVSettingsViewModel

    func makeUIViewController(context: Context) -> PVConflictViewController {
        return PVConflictViewController(conflictsController: viewModel.conflictsController)
    }

    func updateUIViewController(_ uiViewController: PVConflictViewController, context: Context) {
        // Update the view controller if needed
    }
}

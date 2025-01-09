//
//  PVGameLibraryController+PVMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/23/24.
//

import PVUIBase
import SwiftUI
import Foundation
import Combine
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - Menu Delegate

extension PVGameLibraryViewController: PVMenuDelegate {
    public func didTapImports() {
        
    }
    
    public func didTapSettings() {
        // TODO: This is a copy/paste from PVRootViewController+PVMenuDelegate
        let settingsView = PVSettingsView(
            conflictsController: updatesController,
            menuDelegate: self,
            dismissAction: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        .environmentObject(updatesController)
        #if canImport(FreemiumKit)
        .environmentObject(FreemiumKit.shared)
        #endif

        let hostingController = UIHostingController(rootView: settingsView)
        let navigationController = UINavigationController(rootViewController: hostingController)

        self.closeMenu()
        self.present(navigationController, animated: true)
    }
    
    public func didTapHome() {
        
    }
    
    public func didTapAddGames() {
        
    }
    
    public func didTapConsole(with consoleId: String) {
        
    }
    
    public func didTapCollection(with collection: Int) {
        
    }
    
    public func closeMenu() {
        
    }
    

}

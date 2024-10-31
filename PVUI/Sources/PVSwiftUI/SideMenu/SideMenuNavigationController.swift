//
//  SideMenuNavigationController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/24/24.
//

import UIKit
import PVThemes

public final class SideMenuNavigationController: UINavigationController {
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        // Initial setup
//        updateAppearance()
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        
//        // Update appearance when view is about to appear
//        updateAppearance()
//    }
//    
//    override func didMove(toParent parent: UIViewController?) {
//        super.didMove(toParent: parent)
//        
//        // Update appearance when moved to a new parent
//        updateAppearance()
//    }
//    
//    private func updateAppearance() {
//        if parent is SideNavigationController {
//            applyCustomTheme()
//        } else {
//            resetToDefaultTheme()
//        }
//    }
//    
//    private func applyCustomTheme() {
//        let palette = ThemeManager.shared.currentPalette
//        let appearance = UINavigationBarAppearance()
//        appearance.configureWithOpaqueBackground()
//        appearance.backgroundColor = palette.gameLibraryHeaderBackground
//        appearance.titleTextAttributes = [.foregroundColor: palette.gameLibraryHeaderText]
//        appearance.largeTitleTextAttributes = [.foregroundColor: ThemeManager.shared.cu ]
//        
//        navigationBar.standardAppearance = appearance
//        navigationBar.scrollEdgeAppearance = appearance
//        navigationBar.compactAppearance = appearance
//        
//        navigationBar.tintColor = .white // This affects the color of the back button and other bar button items
//    }
//    
//    private func resetToDefaultTheme() {
//        let defaultAppearance = UINavigationBarAppearance()
//        defaultAppearance.configureWithDefaultBackground()
//        
//        navigationBar.standardAppearance = defaultAppearance
//        navigationBar.scrollEdgeAppearance = defaultAppearance
//        navigationBar.compactAppearance = defaultAppearance
//        
//        navigationBar.tintColor = nil // Reset to default tint color
//    }
}

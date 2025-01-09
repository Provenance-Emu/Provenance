//
//  PVRootViewNavigationController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/24/24.
//


import UIKit
import PVThemes
import Perception

/// Custom themed `UINavigationController` for the main center view
/// that's embedded in the SideNavigationController
public final class PVRootViewNavigationController: UINavigationController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initial setup
        updateAppearance()
        _initThemeListener()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update appearance when view is about to appear
        updateAppearance()
    }
    
    public override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        // Update appearance when moved to a new parent
        updateAppearance()
    }
    
    private func updateAppearance() {
        if parent is SideNavigationController {
            applyCustomTheme()
        } else {
            resetToDefaultTheme()
        }
    }
    
    private func applyCustomTheme() {
        let palette = ThemeManager.shared.currentPalette
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = palette.gameLibraryHeaderBackground
        appearance.titleTextAttributes = [.foregroundColor: palette.gameLibraryHeaderText]
        appearance.largeTitleTextAttributes = [.foregroundColor: palette.gameLibraryHeaderText ]
        
#if !os(tvOS)
        if #available (iOS 17.0, tvOS 17.0, *) {
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        }
#endif
        navigationBar.tintColor = palette.defaultTintColor // This affects the color of the back button and other bar button items
    }
    
    private func resetToDefaultTheme() {
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
#if !os(tvOS)
        if #available (iOS 17.0, tvOS 17.0, *) {
            navigationBar.standardAppearance = defaultAppearance
            navigationBar.scrollEdgeAppearance = defaultAppearance
            navigationBar.compactAppearance = defaultAppearance
        }
#endif
        
        navigationBar.tintColor = nil // Reset to default tint color
    }
    
    var paletteListener: Any?
    func _initThemeListener() {
        if #available(iOS 17.0, tvOS 17.0, *) {
            paletteListener = withObservationTracking {
                _ = ThemeManager.shared.currentPalette
            } onChange: { [unowned self] in
                DLOG("changed: \(ThemeManager.shared.currentPalette.name)")
                Task.detached { @MainActor in
                    self.applyCustomTheme()
                }
            }
        } else {
            paletteListener = withPerceptionTracking {
                _ = ThemeManager.shared.currentPalette
            } onChange: {
                print("changed: ", ThemeManager.shared.currentPalette)
                Task.detached { @MainActor in
                    self.applyCustomTheme()
                }
            }

            // Fallback for earlier versions
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleThemeChange),
                name: .themeDidChange, // You need to define this notification name in ThemeManager
                object: nil
            )
        }
    }
    
    // Add this method to handle theme changes for earlier versions
    @objc private func handleThemeChange() {
        print("changed: ", ThemeManager.shared.currentPalette)
        DispatchQueue.main.async { [weak self] in
            self?.applyCustomTheme()
        }
    }

    // Don't forget to remove the observer when it's no longer needed
    deinit {
        if #unavailable(iOS 17.0, tvOS 17.0) {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

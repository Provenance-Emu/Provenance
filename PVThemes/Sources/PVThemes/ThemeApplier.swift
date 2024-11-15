//
//  ThemeApplier.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 10/7/24.
//

import PVLogging
import PVSettings
import UIKit

public extension ThemeManager {
    @MainActor
    class func applySavedTheme() {
        DLOG("Applying saved theme")

        // Read the theme from PVSettings
        let savedThemeOption = Defaults[.theme]
        DLOG("Theme option read from Defaults: \(savedThemeOption)")

        // Convert the saved theme option to iOSTheme
        let paletteToApply: any UXThemePalette
        switch savedThemeOption {
        case .standard(let option):
            switch option {
            case .light:
                paletteToApply = ProvenanceThemes.light.palette
            case .dark:
                paletteToApply = ProvenanceThemes.dark.palette
            case .auto:
                // Determine based on system setting
                let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
                paletteToApply = isDarkMode ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette
            }
        case .cga(let option):
            let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            let autoPalette = isDarkMode ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette

            paletteToApply = CGAThemes(rawValue: option.rawValue)?.palette ?? autoPalette
        }

        DLOG("Applying palette: \(paletteToApply)")
        ThemeManager.shared.setCurrentPalette(paletteToApply)
    }
}

public extension ThemeManager {
    @MainActor
    class func applyPalette(_ palette: any UXThemePalette) {
        DLOG("Setting palette: \(palette)")

        // Apply theme to various UIKit components
   
        configureActionSheets(palette)
        configureActivityIndicator(palette)
        configureBarButtonItems(palette)
//        configureCollectionViews(palette)
        configureInterfaceStyle(palette)
//        configureNavigationBar(palette)
        configureSegmentedControl(palette)
        configurePageControl(palette)
        configureSlider(palette)
        configureStatusBar(palette)
        configureSwitches(palette)
        configureTabBar(palette)
        configureTableViews(palette)
        configureTextInputs(palette)
        configureUISearchBar(palette)
        configureUIView(palette)
        configureUIWindow(palette)

        DLOG("Palette \(palette.name) application completed.")
    }

    /// Status Bar
    /// - Parameter color: Color to set the status bar
    @MainActor
    private class func styleStatusBar(withColor color: UIColor) {
        #if !os(tvOS) && !os(macOS)
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
           let statusBarManager = keyWindow.windowScene?.statusBarManager {
            let statusBar = UIView(frame: statusBarManager.statusBarFrame)
            statusBar.backgroundColor = color
            keyWindow.addSubview(statusBar)
        }
        #endif
    }
    
    /// Status Bar
    /// - Parameter theme: current iOSTheme
    @MainActor
    private class func configureStatusBar(_ palette: any UXThemePalette) {
        #if os(iOS)
        // Configure status bar
        if let statusBarColor = palette.statusBarColor {
            styleStatusBar(withColor: statusBarColor)
            DLOG("Status bar color: \(statusBarColor.debugDescription)")
        }
        #endif
    }
    
    /// UINavigation Bar
    /// - Parameter theme: current iOSTheme
    @MainActor
    private class func configureNavigationBar(_ palette: any UXThemePalette) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = palette.navigationBarBackgroundColor
        
        if let navigationBarTitleColor = palette.navigationBarTitleColor {
            appearance.titleTextAttributes = [.foregroundColor: palette.navigationBarTitleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: palette.navigationBarTitleColor]
        }
        
        if #available(iOS 17.0, tvOS 17.0, *) {
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            if #available(iOS 15.0, *) {
                UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
            }
            UINavigationBar.appearance().tintColor = palette.barButtonItemTint
        }
        DLOG("Navigation bar - tintColor: \(palette.barButtonItemTint?.debugDescription ?? "nil"), backgroundColor: \(palette.navigationBarBackgroundColor?.debugDescription ?? "nil")")
    }

    // MARK: - UIKit Component Theming

    @MainActor
    private class func configureUIView(_ palette: any UXThemePalette) {
        // Apply general UIView appearance
        UIView.appearance().tintColor = palette.defaultTintColor
//        UIView.appearance().backgroundColor = palette.uiviewBackground
        DLOG("UIView appearance - tintColor: \(palette.defaultTintColor?.debugDescription ?? "nil"), backgroundColor: \(palette.uiviewBackground?.debugDescription ?? "nil")")
    }
    
    @MainActor
    private class func configureUIWindow(_ palette: any UXThemePalette) {
        // Apply general UIWindow appearance
        UIView.appearance().tintColor = palette.defaultTintColor
//        UIView.appearance().backgroundColor = palette.uiviewBackground
        DLOG("UIWindow appearance - tintColor: \(palette.defaultTintColor?.debugDescription ?? "nil"), backgroundColor: \(palette.uiviewBackground?.debugDescription ?? "nil")")
    }


    @MainActor
    private class func configureBarButtonItems(_ palette: any UXThemePalette) {
        UIBarButtonItem.appearance().tintColor = palette.barButtonItemTint
        DLOG("Bar button items - tintColor: \(palette.barButtonItemTint?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureSwitches(_ palette: any UXThemePalette) {
        #if !os(tvOS)
        UISwitch.appearance().onTintColor = palette.switchON
        #if !targetEnvironment(macCatalyst)
        UISwitch.appearance().thumbTintColor = palette.switchThumb
        #endif
        DLOG("Switches - onTintColor: \(palette.switchON?.debugDescription ?? "nil"), thumbTintColor: \(palette.switchThumb?.debugDescription ?? "nil")")
        #endif
    }

    @MainActor
    private class func configureTableViews(_ palette: any UXThemePalette) {
        UITableView.appearance().backgroundColor = palette.tableViewBackgroundColor
        #if !os(tvOS)
        UITableView.appearance().separatorColor = palette.settingsSeperator
        #endif
        DLOG("Table views - backgroundColor: \(palette.tableViewBackgroundColor?.debugDescription ?? "nil"), separatorColor: \(palette.settingsSeperator?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureCollectionViews(_ palette: any UXThemePalette) {
        UICollectionViewCell.appearance {
            $0.backgroundColor = palette.gameLibraryCellBackground
            $0.tintColor = palette.gameLibraryCellText
        }
        UICollectionView.appearance().backgroundColor = palette.gameLibraryBackground
        DLOG("Collection views - backgroundColor: \(palette.gameLibraryBackground.debugDescription)")
    }

    @MainActor
    private class func configureTextInputs(_ palette: any UXThemePalette) {
        UITextField.appearance().keyboardAppearance = palette.keyboardAppearance
        UISearchBar.appearance().keyboardAppearance = palette.keyboardAppearance
        
        UITextField.appearance().backgroundColor = palette.gameLibraryBackground
        UITextField.appearance().textColor = palette.gameLibraryText
        
        DLOG("Text inputs - keyboardAppearance: \(palette.keyboardAppearance)")
    }
    
    @MainActor
    private class func configureUISearchBar(_ palette: any UXThemePalette) {
        UISearchBar.appearance().backgroundColor = palette.menuBackground
        UISearchBar.appearance().tintColor = palette.menuText
        UISearchBar.appearance().barTintColor = palette.menuBackground
        UISearchBar.appearance().searchTextField.textColor = palette.menuText
        UISearchTextField.appearance().tokenBackgroundColor = palette.menuHeaderBackground
        UISearchTextField.appearance().tintColor = palette.menuIconTint
        UISearchTextField.appearance().textColor = palette.menuText
        
        DLOG("UISearchBar - backgroundColor: \(palette.settingsCellBackground?.debugDescription ?? "nil"), tintColor: \(palette.gameLibraryText.debugDescription)")
    }


    @MainActor
    private class func configureActionSheets(_ palette: any UXThemePalette) {
        if let actionSystemView = NSClassFromString("_UIInterfaceActionRepresentationsSequenceView") as? UIView.Type {
            actionSystemView.appearance().backgroundColor = palette.settingsCellBackground
            actionSystemView.appearance().tintColor = palette.gameLibraryText
            DLOG("Action sheets - backgroundColor: \(palette.settingsCellBackground?.debugDescription ?? "nil"), tintColor: \(palette.gameLibraryText.debugDescription)")

            UILabel.appearance(whenContainedInInstancesOf: [actionSystemView]).textColor = palette.gameLibraryText
            UILabel.appearance(whenContainedInInstancesOf: [actionSystemView]).tintColor = palette.defaultTintColor
            DLOG("Action sheet labels - textColor: \(palette.gameLibraryText.debugDescription), tintColor: \(palette.defaultTintColor?.debugDescription ?? "nil")")
        }
    }

    @MainActor
    private class func configureTabBar(_ palette: any UXThemePalette) {
        UITabBar.appearance {
            $0.tintColor = palette.defaultTintColor
            $0.unselectedItemTintColor = palette.segmentedControlTint
            $0.barTintColor = palette.segmentedControlSelectedTint
        }
        DLOG("Tab bar - tintColor: \(palette.defaultTintColor?.debugDescription ?? "nil"), barTintColor: \(palette.tabBarBackground?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureSegmentedControl(_ palette: any UXThemePalette) {
        UISegmentedControl.appearance().selectedSegmentTintColor = palette.defaultTintColor
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: palette.gameLibraryText], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: palette.settingsCellBackground ?? .white], for: .selected)
        DLOG("Segmented control - selectedSegmentTintColor: \(palette.defaultTintColor?.debugDescription ?? "nil"), normalTextColor: \(palette.gameLibraryText.debugDescription), selectedTextColor: \(palette.settingsCellBackground?.debugDescription ?? "nil")")
    }
    
    @MainActor
    private class func configurePageControl(_ palette: any UXThemePalette) {
        UIPageControl.appearance().currentPageIndicatorTintColor = palette.switchON?.saturation(0.8)
        UIPageControl.appearance().pageIndicatorTintColor = palette.switchON?.saturation(0.3) ?? palette.switchThumb
        DLOG("Page control - configurePageControl - currentPageIndicatorTintColor: \(palette.defaultTintColor?.debugDescription ?? "nil"), pageIndicatorTintColor: \(palette.gameLibraryText.debugDescription ?? "") ")
    }

    @MainActor
    private class func configureSlider(_ palette: any UXThemePalette) {
        #if !os(tvOS)
        UISlider.appearance().thumbTintColor = palette.defaultTintColor
        UISlider.appearance().minimumTrackTintColor = palette.defaultTintColor?.withAlphaComponent(0.5)
        UISlider.appearance().maximumTrackTintColor = palette.settingsSeperator
        DLOG("Slider - thumbTintColor: \(palette.defaultTintColor?.debugDescription ?? "nil"), minimumTrackTintColor: \(palette.defaultTintColor?.withAlphaComponent(0.5).debugDescription ?? "nil"), maximumTrackTintColor: \(palette.settingsSeperator?.debugDescription ?? "nil")")
        #endif
    }

    @MainActor
    private class func configureActivityIndicator(_ palette: any UXThemePalette) {
        UIActivityIndicatorView.appearance().color = palette.defaultTintColor
        DLOG("Activity indicator - color: \(palette.defaultTintColor?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureInterfaceStyle(_ palette: any UXThemePalette) {
        let interfaceStyle: UIUserInterfaceStyle = palette.dark ? .dark : .light
        UIApplication.shared.windows.forEach { $0.overrideUserInterfaceStyle = interfaceStyle }
        DLOG("Interface style: \(interfaceStyle == .dark ? "Dark" : "Light")")
    }
}

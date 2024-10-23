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
        let themeToApply: iOSTheme
        switch savedThemeOption {
        case .standard(let option):
            switch option {
            case .light:
                themeToApply = ProvenanceThemes.light.palette
            case .dark:
                themeToApply = ProvenanceThemes.dark.palette
            case .auto:
                // Determine based on system setting
                let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
                themeToApply = isDarkMode ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette
            }
        case .cga(let option):
            themeToApply = CGAThemes(rawValue: option.rawValue)?.palette ?? ProvenanceThemes.dark.palette
        }

        DLOG("Applying theme: \(themeToApply)")
        applyTheme(themeToApply)
    }
}

public extension ThemeManager {
    @MainActor
    class func applyTheme(_ theme: iOSTheme) {
        DLOG("Setting theme: \(theme)")
//        configureNavigationBar(withTheme: theme)
//        configureStatusBar(withTheme: theme)
//
        // Apply theme to various UIKit components
//        configureUIView(theme)
//        configureBarButtonItems(theme)
//        configureSwitches(theme)
//        configureTableViews(theme)
//        configureCollectionViews(theme)
//        configureTextInputs(theme)
//        configureActionSheets(theme)
//        configureTabBar(theme)
//        configureSegmentedControl(theme)
//        configureSlider(theme)
//        configureActivityIndicator(theme)
//        configureInterfaceStyle(theme)

        DLOG("Theme application completed.")
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
    private class func configureStatusBar(withTheme theme: iOSTheme) {
        #if os(iOS)
        // Configure status bar
        if let statusBarColor = theme.statusBarColor {
            styleStatusBar(withColor: statusBarColor)
            DLOG("Status bar color: \(statusBarColor.debugDescription)")
        }
        #endif
    }
    
    /// UINavigation Bar
    /// - Parameter theme: current iOSTheme
    @MainActor
    private class func configureNavigationBar(withTheme theme: iOSTheme) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme.navigationBarBackgroundColor
        // TODO: Add `navigationBarTitleColor` to themes
        if let navigationBarTitleColor = theme.navigationBarTitleColor {
            appearance.titleTextAttributes = [.foregroundColor: theme.navigationBarTitleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: theme.navigationBarTitleColor]
        }

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        }

        UINavigationBar.appearance().tintColor = theme.barButtonItemTint
        DLOG("Navigation bar - tintColor: \(theme.barButtonItemTint?.debugDescription ?? "nil"), backgroundColor: \(theme.navigationBarBackgroundColor?.debugDescription ?? "nil")")
    }

    // MARK: - UIKit Component Theming

    @MainActor
    private class func configureUIView(_ theme: iOSTheme) {
        // Apply general UIView appearance
        UIView.appearance().tintColor = theme.defaultTintColor
        UIView.appearance().backgroundColor = theme.uiviewBackground
        DLOG("UIView appearance - tintColor: \(theme.defaultTintColor?.debugDescription ?? "nil"), backgroundColor: \(theme.uiviewBackground?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureBarButtonItems(_ theme: iOSTheme) {
        UIBarButtonItem.appearance().tintColor = theme.barButtonItemTint
        DLOG("Bar button items - tintColor: \(theme.barButtonItemTint?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureSwitches(_ theme: iOSTheme) {
        #if !os(tvOS)
        UISwitch.appearance().onTintColor = theme.switchON
        #if !targetEnvironment(macCatalyst)
        UISwitch.appearance().thumbTintColor = theme.switchThumb
        #endif
        DLOG("Switches - onTintColor: \(theme.switchON?.debugDescription ?? "nil"), thumbTintColor: \(theme.switchThumb?.debugDescription ?? "nil")")
        #endif
    }

    @MainActor
    private class func configureTableViews(_ theme: iOSTheme) {
        UITableView.appearance().backgroundColor = theme.navigationBarBackgroundColor
        UITableView.appearance().separatorColor = theme.settingsSeperator
        DLOG("Table views - backgroundColor: \(theme.navigationBarBackgroundColor?.debugDescription ?? "nil"), separatorColor: \(theme.settingsSeperator?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureCollectionViews(_ theme: iOSTheme) {
        UICollectionView.appearance().backgroundColor = theme.gameLibraryBackground
        DLOG("Collection views - backgroundColor: \(theme.gameLibraryBackground.debugDescription)")
    }

    @MainActor
    private class func configureTextInputs(_ theme: iOSTheme) {
        UITextField.appearance().keyboardAppearance = theme.keyboardAppearance
        UISearchBar.appearance().keyboardAppearance = theme.keyboardAppearance
        DLOG("Text inputs - keyboardAppearance: \(theme.keyboardAppearance)")
    }

    @MainActor
    private class func configureActionSheets(_ theme: iOSTheme) {
        if let actionSystemView = NSClassFromString("_UIInterfaceActionRepresentationsSequenceView") as? UIView.Type {
            actionSystemView.appearance().backgroundColor = theme.settingsCellBackground
            actionSystemView.appearance().tintColor = theme.gameLibraryText
            DLOG("Action sheets - backgroundColor: \(theme.settingsCellBackground?.debugDescription ?? "nil"), tintColor: \(theme.gameLibraryText.debugDescription)")

            UILabel.appearance(whenContainedInInstancesOf: [actionSystemView]).textColor = theme.gameLibraryText
            UILabel.appearance(whenContainedInInstancesOf: [actionSystemView]).tintColor = theme.defaultTintColor
            DLOG("Action sheet labels - textColor: \(theme.gameLibraryText.debugDescription), tintColor: \(theme.defaultTintColor?.debugDescription ?? "nil")")
        }
    }

    @MainActor
    private class func configureTabBar(_ theme: iOSTheme) {
        UITabBar.appearance().tintColor = theme.defaultTintColor
        UITabBar.appearance().barTintColor = theme.tabBarBackground
        DLOG("Tab bar - tintColor: \(theme.defaultTintColor?.debugDescription ?? "nil"), barTintColor: \(theme.tabBarBackground?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureSegmentedControl(_ theme: iOSTheme) {
        UISegmentedControl.appearance().selectedSegmentTintColor = theme.defaultTintColor
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: theme.gameLibraryText], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: theme.settingsCellBackground ?? .white], for: .selected)
        DLOG("Segmented control - selectedSegmentTintColor: \(theme.defaultTintColor?.debugDescription ?? "nil"), normalTextColor: \(theme.gameLibraryText.debugDescription), selectedTextColor: \(theme.settingsCellBackground?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureSlider(_ theme: iOSTheme) {
        UISlider.appearance().thumbTintColor = theme.defaultTintColor
        UISlider.appearance().minimumTrackTintColor = theme.defaultTintColor?.withAlphaComponent(0.5)
        UISlider.appearance().maximumTrackTintColor = theme.settingsSeperator
        DLOG("Slider - thumbTintColor: \(theme.defaultTintColor?.debugDescription ?? "nil"), minimumTrackTintColor: \(theme.defaultTintColor?.withAlphaComponent(0.5).debugDescription ?? "nil"), maximumTrackTintColor: \(theme.settingsSeperator?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureActivityIndicator(_ theme: iOSTheme) {
        UIActivityIndicatorView.appearance().color = theme.defaultTintColor
        DLOG("Activity indicator - color: \(theme.defaultTintColor?.debugDescription ?? "nil")")
    }

    @MainActor
    private class func configureInterfaceStyle(_ theme: iOSTheme) {
        let interfaceStyle: UIUserInterfaceStyle = theme.dark ? .dark : .light
        UIApplication.shared.windows.forEach { $0.overrideUserInterfaceStyle = interfaceStyle }
        DLOG("Interface style: \(interfaceStyle == .dark ? "Dark" : "Light")")
    }
}

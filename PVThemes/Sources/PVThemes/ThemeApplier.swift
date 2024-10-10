
//
//  ThemeApplier.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 10/7/24.
//

@available(macOS 14.0, *)
private extension ThemeManager {
    @MainActor
    class func setTheme(_ theme: iOSTheme) {
        configureNavigationBar(withTheme: theme)
        
#if canImport(UIKit)
        // MARK: UIBarButtonItem
        UIBarButtonItem.appearance {
            $0.tintColor = theme.barButtonItemTint
        }

        // MARK: UISwitch
        #if !os(tvOS)
        UISwitch.appearance {
            $0.onTintColor = theme.switchON
            #if !targetEnvironment(macCatalyst)
            $0.thumbTintColor = theme.switchThumb
            #endif
        }

        #if false
        UITableView.appearance {
            $0.backgroundColor = theme.settingsHeaderBackground
            $0.separatorColor = theme.settingsSeperator
        }
        #endif
        #endif
#else
#endif
        #if false
        UICollectionView.appearance {
            $0.backgroundColor = theme.gameLibraryBackground
        }
        #endif

        // Keyboard Style
        #if canImport(UIKit)
        UITextField.appearance {
            $0.keyboardAppearance = theme.keyboardAppearance
        }

        UISearchBar.appearance {
            $0.keyboardAppearance = theme.keyboardAppearance
        }

        // Force touch sheet // _UIInterfaceActionSystemRepresentationView
        if let actionSystemView = NSClassFromString("_UIInterfaceActionRepresentationsSequenceView") as? (UIView.Type) {
            actionSystemView.appearance {
                $0.backgroundColor = theme.settingsCellBackground
                #if false
                $0.layer.borderColor = theme.settingsCellText?.withAlphaComponent(0.6).cgColor
                $0.layer.cornerRadius = 10.0
                $0.layer.borderWidth = 0.5
                #endif
                $0.tintColor = theme.gameLibraryText
            }

            appearance(inAny: [actionSystemView.self]) {
                UILabel.appearance {
                    $0.textColor = theme.gameLibraryText
                }
            }
        }
        #endif

        #if os(iOS)
        // Status bar
        if let statusBarColor = theme.statusBarColor {
            styleStatusBar(withColor: statusBarColor)
        }
        #endif
    }
    
    /// Status Bar
    /// - Parameter color: Color to set the status bar
    @MainActor
    class func styleStatusBar(withColor color: UIColor) {
        #if !os(tvOS) && !os(macOS)
        let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }

        guard
            let scene = keyWindow?.windowScene,
            let manager = scene.statusBarManager else {
            return
        }
        
        let statusBar = statusBarView ?? UIView()
        statusBar.frame = manager.statusBarFrame
        statusBar.backgroundColor = color
        statusBarView = statusBar
        keyWindow?.addSubview(statusBar)
        #endif
    }
    
    /// UINavigation Bar
    /// - Parameter theme: current iOSTheme
    @MainActor
    class private func configureNavigationBar(withTheme theme: iOSTheme) {
        
        #if true
        UINavigationBar.appearance {
            // This makes the navigation bar's background extend underneath the status bar
            $0.tintColor = theme.barButtonItemTint
        //            #if !os(tvOS)
        //            $0.barStyle = theme.navigationBarStyle
        //            #endif
            $0.isTranslucent = true
        }

        UIView.appearance {
            $0.tintColor = theme.defaultTintColor
        }
        #endif
                
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBlue // Or any color you prefer
        
        // This makes the navigation bar's background extend underneath the status bar
        appearance.backgroundEffect = nil
        
        // For iOS 15 and later, you might also want to set this:
        if #available(iOS 15.0, *) {
            appearance.shadowColor = .clear
        }
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // For iOS 15 and later, you might also want to set this:
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        }
    }
}

//
//  ThemeManager.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//

import Foundation
import SwiftMacros
@_exported import UIKit

//@Singleton
@Observable
public final class ThemeManager {

    nonisolated(unsafe) public static let shared: ThemeManager = .init()
    private init() { }

    public let themes: Array<iOSTheme> = []
    public private(set) var currentTheme: iOSTheme = ProvenanceThemes.default.palette

    public func setCurrentTheme(_ theme: iOSTheme) {
        // Set new value to obserable variable
        currentTheme = theme
        Task {
            await UIApplication.shared.refreshAppearance(animated: true)
        }
    }

    @MainActor
    static weak var statusBarView: UIView?
}

private extension ThemeManager {
    class func styleStatusBar(withColor color: UIColor) {
        #if !os(tvOS)
        DispatchQueue.main.async {
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
        }
        #endif
    }
    
    @MainActor
    class func setTheme(_ theme: iOSTheme) {
        #if false
        UINavigationBar.appearance {
            $0.backgroundColor = theme.navigationBarBackgroundColor
            $0.tintColor = theme.barButtonItemTint
            #if !os(tvOS)
            $0.barStyle = theme.navigationBarStyle
            #endif
            $0.isTranslucent = true
        }

        UIView.appearance {
            $0.tintColor = theme.defaultTintColor
        }
        #endif

        UIBarButtonItem.appearance {
            $0.tintColor = theme.barButtonItemTint
        }

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

        #if false
        UICollectionView.appearance {
            $0.backgroundColor = theme.gameLibraryBackground
        }
        #endif

        // Keyboard Style
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

        #if os(iOS)
        // Status bar
        if let statusBarColor = theme.statusBarColor {
            styleStatusBar(withColor: statusBarColor)
        }
        #endif
    }
}

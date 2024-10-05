//
//  ThemeManager.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//

import Foundation
import SwiftMacros
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

//@Singleton
@available(macOS 14.0, *)
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

@available(macOS 14.0, *)
private extension ThemeManager {
    class func styleStatusBar(withColor color: UIColor) {
        #if !os(tvOS) && !os(macOS)
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
#if canImport(UIKit)
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
}

extension FloatingPoint {
    
    /// Clamps a floating point to a range
    /// - Parameter range: Range to clamp to
    /// - Returns: New value clamped to range
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

public extension UIColor {
    
    /// Subtracts from the saturation of the current UIColor
    /// Also takes a negative value or you can use `addSaturation()`
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted saturation
    func subtractSaturation(_ adjustment: CGFloat) -> UIColor {
        addSaturation(adjustment * -1)
    }
    
    /// Adds to the saturation of the current UIColor
    /// Also takes a negative value or you can use `subtractSaturation()`
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted saturation
    func addSaturation(_ adjustment: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted saturation
            // It is also range bound from 0 to 1
            let newSaturation = (saturation + adjustment).clamped(to: 0...1)
            return UIColor(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
    
    /// Adjust the saturation of the current UIColor
    /// - Parameter newSaturation: From 0...1
    /// - Returns: Color with adusted saturation
    func saturation(_ newSaturation: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted saturation
            return UIColor(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
    
    /// Adjust the brightness of the current UIColor
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted brightness
    func brightness(_ newBrighness: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted brightness
            return UIColor(hue: hue, saturation: saturation, brightness: newBrighness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
    
    /// Adjust the hue of the current UIColor
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted hue
    func hue(_ newHue: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted hue
            return UIColor(hue: newHue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
}

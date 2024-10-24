//
//  PVUINavigationController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

#if !os(tvOS)
#if canImport(UIKit)
#if canImport(UIKit)
import UIKit
#endif
import PVThemes

final class PVUINavigationController: UINavigationController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return ThemeManager.shared.currentPalette.dark ? .lightContent : .darkContent
    }
}
#endif
#endif

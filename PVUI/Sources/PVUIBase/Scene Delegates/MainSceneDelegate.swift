//
//  MainSceneDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import UIKit

class MainSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Check if this is an external display scene
        if windowScene.screen == .main {
            window = UIWindow(windowScene: windowScene)
            window?.backgroundColor = .black


            window?.makeKeyAndVisible()
        }
    }

    #if !os(tvOS)
    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {
        // Handle screen orientation changes
        if windowScene.screen == .main {
            window?.frame = windowScene.coordinateSpace.bounds
        }
    }
    #endif
}

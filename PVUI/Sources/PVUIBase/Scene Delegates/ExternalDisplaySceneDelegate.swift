//
//  ExternalDisplaySceneDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import UIKit
import PVThemes

//extension UIApplication
//{
//    var isExternalDisplayConnected: Bool {
//        let scene = UIApplication.shared.connectedScenes.first { $0.session.role == .windowExternalDisplay }
//        return scene != nil
//    }
//
//    var externalDisplayScene: ExternalDisplayScene? {
//        let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? ExternalDisplayScene }).first(where: { $0.session.role == .windowExternalDisplay })
//        return scene
//    }
//}


class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var metalViewController: PVMetalViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.backgroundColor = .black

        // Create a basic root view controller to host our Metal content
        let rootViewController = UIViewController()
        rootViewController.view.backgroundColor = .black
        window?.rootViewController = rootViewController

        window?.makeKeyAndVisible()
    }

    func setMetalViewController(_ viewController: PVMetalViewController) {
        metalViewController = viewController

        guard let window = window,
              let rootViewController = window.rootViewController else { return }

        // Remove previous Metal view if it exists
        metalViewController?.view.removeFromSuperview()

        // Add Metal view to root view controller
        viewController.view.frame = rootViewController.view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        rootViewController.view.addSubview(viewController.view)

        // Add as child view controller to maintain proper lifecycle
        rootViewController.addChild(viewController)
        viewController.didMove(toParent: rootViewController)
    }

    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {
        // Handle screen orientation changes
        if windowScene.screen != .main {
            window?.frame = windowScene.coordinateSpace.bounds
        }
    }
}

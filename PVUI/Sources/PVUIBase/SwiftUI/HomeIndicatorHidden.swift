//
//  HomeIndicatorHidden.swift
//  Provenance
//
//  Created by Joseph Mattiello on 4/2/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI

/// View modifier to hide the home indicator
public struct HomeIndicatorHidden: ViewModifier {
    /// Hide the home indicator using UIKit's prefersHomeIndicatorAutoHidden
    public func body(content: Content) -> some View {
        content
            .background(HomeIndicatorHiddenHelper())
    }

    /// Helper view to integrate with UIKit
    private struct HomeIndicatorHiddenHelper: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> UIViewController {
            HomeIndicatorHiddenController()
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        }

        /// Custom UIViewController that hides the home indicator
        private class HomeIndicatorHiddenController: UIViewController {
            override var prefersHomeIndicatorAutoHidden: Bool {
                return true
            }

            override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
                return .all
            }

            override func viewDidLoad() {
                super.viewDidLoad()

                // Make the view completely transparent and non-interactive
                view.backgroundColor = .clear
                view.isUserInteractionEnabled = false
            }
        }
    }
}

/// Extension to provide a convenient ViewModifier for View
public extension View {
    /// Hide the home indicator and defer system gestures
    func hideHomeIndicator() -> some View {
        modifier(HomeIndicatorHidden())
    }
}

/// Extension to UIWindow to help enforce hiding home indicator across the entire app
public extension UIWindow {
    /// Sets home indicator auto-hidden for all view controllers in the hierarchy
    func setHomeIndicatorAutoHidden(_ autoHidden: Bool = true) {
        // Start with the root controller
        if let rootController = self.rootViewController {
            // Apply to root controller
            applyHomeIndicatorSettings(to: rootController, autoHidden: autoHidden)

            // Force update of the system UI
            rootController.setNeedsUpdateOfHomeIndicatorAutoHidden()
            rootController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
    }

    /// Helper method to apply settings recursively to all view controllers
    private func applyHomeIndicatorSettings(to viewController: UIViewController, autoHidden: Bool) {
        // Use Objective-C runtime to set the property
        // This is a workaround since these properties are read-only
        let selector = NSSelectorFromString("_setContentHuggingPriorities:")
        if viewController.responds(to: selector) {
            // Set the home indicator preferences
            objc_setAssociatedObject(viewController,
                                    "prefersHomeIndicatorAutoHidden",
                                    autoHidden,
                                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        // Apply to all child view controllers
        for childVC in viewController.children {
            applyHomeIndicatorSettings(to: childVC, autoHidden: autoHidden)
        }

        // Apply to presented view controller
        if let presentedVC = viewController.presentedViewController {
            applyHomeIndicatorSettings(to: presentedVC, autoHidden: autoHidden)
        }
    }
}

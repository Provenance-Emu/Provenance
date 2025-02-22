//
//  PVRootViewNavigationController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/24/24.
//


import UIKit
import PVThemes
import Perception
import SwiftUI

/// Custom themed `UINavigationController` for the main center view
/// that's embedded in the SideNavigationController
public final class PVRootViewNavigationController: UINavigationController {

    /// Constants for styling
    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static let borderWidth: CGFloat = 4
        static let backgroundOpacity: CGFloat = 0.2
    }

    /// Custom background view that provides the retro styling
    private class RetroBackgroundView: UIView {
        private let borderLayer = CAShapeLayer()
        private var palette: (any UXThemePalette)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        private func setup() {
            backgroundColor = .clear
            layer.addSublayer(borderLayer)
        }

        func updateStyle(with palette: any UXThemePalette) {
            self.palette = palette

            // Background with opacity
            backgroundColor = palette.gameLibraryBackground.withAlphaComponent(Constants.backgroundOpacity)

            // Update border
            borderLayer.strokeColor = palette.defaultTintColor?.cgColor
            borderLayer.fillColor = UIColor.clear.cgColor
            borderLayer.lineWidth = Constants.borderWidth

            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            // Create path for rounded corners
            let path = UIBezierPath(roundedRect: bounds.insetBy(dx: Constants.borderWidth / 2, dy: Constants.borderWidth / 2),
                                  cornerRadius: Constants.cornerRadius)
            borderLayer.path = path.cgPath

            // Ensure border is on top
            layer.insertSublayer(borderLayer, at: 1)
        }
    }

    private let retroBackgroundView = RetroBackgroundView()

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Add custom background view
        navigationBar.addSubview(retroBackgroundView)
        retroBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        // Extend background below navigation bar
        NSLayoutConstraint.activate([
            retroBackgroundView.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor, constant: 8),
            retroBackgroundView.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor, constant: -8),
            retroBackgroundView.topAnchor.constraint(equalTo: navigationBar.topAnchor, constant: -44), // Extend above
            retroBackgroundView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 8)
        ])

        // Send background view to back
        navigationBar.sendSubviewToBack(retroBackgroundView)

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

        // Make the standard navigation bar transparent
        appearance.configureWithTransparentBackground()

        // Style the text
        appearance.titleTextAttributes = [
            .foregroundColor: palette.gameLibraryHeaderText,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]

        appearance.largeTitleTextAttributes = [
            .foregroundColor: palette.gameLibraryHeaderText,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        // Update our custom background
        retroBackgroundView.updateStyle(with: palette)

#if !os(tvOS)
        if #available (iOS 17.0, tvOS 17.0, *) {
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        }
#endif
        // Set tint color for buttons
        navigationBar.tintColor = palette.defaultTintColor
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
        navigationBar.tintColor = nil
        retroBackgroundView.isHidden = true
    }

    var paletteListener: Any?
    func _initThemeListener() {
//        if #available(iOS 17.0, tvOS 17.0, *) {
//            paletteListener = withObservationTracking {
//                _ = ThemeManager.shared.currentPalette
//            } onChange: { [unowned self] in
//                DLOG("changed: \(ThemeManager.shared.currentPalette.name)")
//                Task.detached { @MainActor in
//                    self.applyCustomTheme()
//                }
//            }
//        } else {
//            paletteListener = withPerceptionTracking {
//                _ = ThemeManager.shared.currentPalette
//            } onChange: {
//                print("changed: ", ThemeManager.shared.currentPalette)
//                Task.detached { @MainActor in
//                    self.applyCustomTheme()
//                }
//            }
//
//
//        }

        // Fallback for earlier versions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: .themeDidChange, // You need to define this notification name in ThemeManager
            object: nil
        )
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

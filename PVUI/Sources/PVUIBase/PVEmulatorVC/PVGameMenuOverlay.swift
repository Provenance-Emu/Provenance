//
//  PVGameMenuOverlay.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import UIKit
import SwiftUI
import PVCoreBridge
import PVFeatureFlags
import PVLogging
import PVSettings
import GameController
import PVSupport
import PVLibrary
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// Menu categories
enum MenuCategory {
    case main, core, states, options
    #if !os(tvOS) && !os(macOS) && !targetEnvironment(macCatalyst)
    case skins
    #endif
}

/// A custom menu overlay to replace UIAlertController for game menu options
@MainActor class PVGameMenuOverlay: UIView {

    // MARK: - Properties

    weak var emulatorViewController: PVEmulatorViewController?
    /// The hosting controller for the SwiftUI menu view.
    /// Exposed so the presenter (`PVEmulatorViewController.showMenu`) can call
    /// `addChild` and wire up the proper VC parent-child relationship, which is
    /// required for SwiftUI `.sheet()` presentation to work from within the overlay.
    var hostingController: UIViewController?

    // MARK: - Initialization

    init(frame: CGRect, emulatorViewController: PVEmulatorViewController) {
        super.init(frame: frame)
        self.emulatorViewController = emulatorViewController
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        // Make background transparent - the SwiftUI view will handle the background
        backgroundColor = .clear

        guard let emulatorVC = emulatorViewController else { return }

        let useTileMenu = PVFeatureFlags.shared.isEnabled(.pauseTileMenu)

        // Create the SwiftUI menu view — tile overlay when feature-flagged, classic otherwise
        let hostingVC: UIViewController
        if useTileMenu {
            let tileView = PauseTileMenuView(
                emulatorVC: emulatorVC,
                dismissAction: { [weak self] resumeEmulation in
                    self?.dismiss(resumeEmulation: resumeEmulation)
                }
            )
            #if canImport(FreemiumKit)
            let wrappedTileView = tileView.environmentObject(FreemiumKit.shared)
            hostingVC = UIHostingController(rootView: wrappedTileView)
            #else
            hostingVC = UIHostingController(rootView: tileView)
            #endif
        } else {
            var menuView: some View {
                RetroMenuView(emulatorVC: emulatorVC, dismissAction: { [weak self] resumeEmulation in
                    self?.dismiss(resumeEmulation: resumeEmulation)
                })
                #if canImport(FreemiumKit)
                .environmentObject(FreemiumKit.shared)
                #endif
            }
            hostingVC = UIHostingController(rootView: menuView)
        }

        hostingController = hostingVC
        hostingController?.view.backgroundColor = .clear
        hostingController?.view.isOpaque = false

        // Add the hosting view to our view hierarchy
        if let hostingView = hostingController?.view {
            addSubview(hostingView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    // MARK: - Actions

    @objc func dismiss() {
        dismiss(resumeEmulation: true)
    }

    func dismiss(resumeEmulation: Bool) {
        DLOG("Dismissing custom game menu (resumeEmulation: \(resumeEmulation))")

        // Prefer the emulator VC's own dismissal helper so it can control emulation state
        if let emulatorVC = emulatorViewController {
            emulatorVC.dismissNav(resumeEmulation: resumeEmulation)
            return
        }

        // Fallback: attempt to dismiss the presenting view controller
        var responder: UIResponder? = self
        while responder != nil && !(responder is UIViewController) {
            responder = responder?.next
        }
        if let viewController = responder as? UIViewController {
            viewController.dismiss(animated: true, completion: nil)
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 0
            }, completion: { _ in
                self.removeFromSuperview()
            })
        }
    }

    // This method is no longer needed since cleanup is handled by the view controller
    private func cleanup() {
        // Cleanup is now handled by PVEmulatorViewController's cleanupAfterMenuDismissal method
        // when the modal view controller is dismissed
    }

    // MARK: - Presentation

    // This method is now handled by the view controller presentation
    // but we'll keep it for backward compatibility
    func present(in viewController: UIViewController) {
        // Start with transparent view
        alpha = 0

        // Animate in
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
}

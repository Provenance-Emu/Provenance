//
//  PVGameMenuOverlay.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import UIKit
import SwiftUI
import PVCoreBridge
import PVLogging
import PVSettings
import GameController
import PVSupport
import PVLibrary

// Menu categories
enum MenuCategory {
    case main, states, options, skins
}

/// A custom menu overlay to replace UIAlertController for game menu options
class PVGameMenuOverlay: UIView {
    
    // MARK: - Properties
    
    weak var emulatorViewController: PVEmulatorViewController?
    private var hostingController: UIHostingController<RetroMenuView>?
    
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
        
        // Create the SwiftUI menu view
        let menuView = RetroMenuView(emulatorVC: emulatorVC) { [weak self] in
            self?.dismiss()
        }
        
        // Create and configure the hosting controller
        hostingController = UIHostingController(rootView: menuView)
        hostingController?.view.backgroundColor = .clear
        
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
        DLOG("Dismissing custom game menu")
        
        // Prefer the emulator VC's own dismissal helper so it can resume emulation
        if let emulatorVC = emulatorViewController {
            emulatorVC.dismissNav()
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

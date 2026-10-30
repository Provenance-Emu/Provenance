//
//  PVEmulatoreViewController+Menus.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//

import Foundation
import PVCoreBridge
import SwiftUI

// MARK: Menus
extension PVEmulatorViewController {

#if os(iOS)
    func layoutMenuButton() {
        if let menuButton = self.menuButton {
            let height: CGFloat = 42
            let width: CGFloat = 42
            menuButton.imageView?.contentMode = .center
            let isLandscape = UIDevice.current.orientation.isLandscape
            let leftInset: CGFloat = isLandscape ? view.safeAreaInsets.left : view.safeAreaInsets.left + 10
            let topInset: CGFloat = isLandscape ? 10 : view.safeAreaInsets.top + 5
            let frame = CGRect(x: leftInset, y: topInset, width: width, height: height)
            menuButton.frame = frame
        }
    }
#endif

    @objc public func hideMoreInfo() {
        dismiss(animated: true, completion: { () -> Void in
            self.hideMenu()
        })
    }

    public func hideMenu() {
        if (!core.isOn) {
            return;
        }
        enableControllerInput(false)
        isShowingMenu = false
        if isPresentingPVAlert {
            PVAlertCenter.shared.dismissCurrent()
        }
        // The pause-tile menu is presented as a generic UIViewController hosting
        // a SwiftUI overlay (see showMenu in PVEmulatorViewController+PauseMenu.swift),
        // so the alert dismissal above doesn't reach it. When the user
        // toggles pause again with their controller (e.g. PS5 Options button),
        // controllerPauseButtonPressed lands here and we have to actually dismiss
        // that VC ourselves — otherwise the menu stays on screen and only the
        // Siri Remote Menu button can clear it via the focus engine.
        if let menuVC = menuPresentationViewController, !menuVC.isBeingDismissed {
            menuVC.dismiss(animated: true) { [weak self] in
                self?.menuPresentationViewController = nil
                if let core = self?.core, core.isOn {
                    core.setPauseEmulation(false)
                }
            }
        }
#if os(iOS)
        // if there is a DONE button, press it
        if let nav = presentedViewController as? UINavigationController, !presentedViewController!.isBeingDismissed {
            let top = nav.topViewController?.navigationItem
            for bbi in (top?.leftBarButtonItems ?? []) + (top?.rightBarButtonItems ?? []) {
                if bbi.style == .done || bbi.action == NSSelectorFromString("done:") {
                    _ = bbi.target?.perform(bbi.action, with:bbi)
                }
            }
        }
#endif
        DispatchQueue.main.async { [weak self] in
            self?.playTimeTracker?.updateLastPlayedTime()
        }
        if core.isOn {
            core.setPauseEmulation(false)
        }
    }

    @objc public func showSpeedMenu() {
        var actions = GameSpeed.allCases.map { speed in
            PVAlertAction(speed.description) {
                self.enableControllerInput(false)
                self.isShowingMenu = false
                self.setGameSpeedRespectingAchievements(speed)
                self.core.setPauseEmulation(false)
            }
        }
        let currentSpeedID = actions[safe: core.gameSpeed.rawValue]?.id
        actions.append(.cancel(NSLocalizedString("Cancel", comment: "Cancel")) {
            self.enableControllerInput(false)
            self.isShowingMenu = false
            self.core.setPauseEmulation(false)
        })
        present(PVAlert(title: "Game Speed", style: .actionSheet, actions: actions, preferredActionID: currentSpeedID))
        Task { @MainActor in
            await PVControllerManager.shared.iCadeController?.refreshListener()
        }
    }

    public func showMoreInfo() {
        guard let game = self.game else {
            ELOG("Game is nil, wtf you doing bruh?")
            return
        }

        // Create the SwiftUI view model
        guard let driver = try? RealmGameLibraryDriver() else {
            ELOG("No driver, no ride!")
            return
        }

        let viewModel = GameMoreInfoViewModel(driver: driver, gameId: game.md5Hash ?? "")

        // Create the SwiftUI view
        let gameMoreInfoView = GameMoreInfoView(viewModel: viewModel)
            .environment(\.colorScheme, .dark) // Force dark mode for the retrowave theme

        // Create a hosting controller for the SwiftUI view
        let hostingController = UIHostingController(rootView: gameMoreInfoView)
        hostingController.modalPresentationStyle = .fullScreen

        // Create navigation controller
        let newNav = UINavigationController(rootViewController: hostingController)

        newNav.isModalInPresentation = true

#if os(iOS)
        hostingController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.hideMoreInfo))
        self.present(newNav, animated: true) { () -> Void in }
#else
        hostingController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.hideMoreInfo))
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.hideMoreInfo))
        tap.allowedPressTypes = [.menu]
        hostingController.view.addGestureRecognizer(tap)
        newNav.preferredContentSize = CGSize(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.9)
        self.present(TVFullscreenController(rootViewController: newNav), animated: true)
#endif
        // hideMoreInfo will handle re-enabling controller input
    }

    /// Presents the tile menu at the SKINS route, keeping the game paused.
    /// Call this after the tile-menu has been dismissed (`dismissNav(resumeEmulation: false)`).
    #if os(iOS) && !targetEnvironment(macCatalyst)
    @MainActor
    public func showSkinOptions() {
        enableControllerInput(true)
        isShowingMenu = true
        // Mirror showMenu's indicator-overlay lifecycle to avoid z-order/interaction conflicts.
        temporarilyHideIndicatorOverlay()

        let skinMenuView = PauseTileMenuView(
            emulatorVC: self,
            dismissAction: { [weak self] resumeEmulation in
                guard let self = self else { return }
                self.dismissNav(resumeEmulation: resumeEmulation) { [weak self] in
                    self?.restoreIndicatorOverlay()
                }
            },
            initialRoute: .skins
        )
        let hostingVC = UIHostingController(rootView: skinMenuView)
        hostingVC.modalPresentationStyle = .overFullScreen
        hostingVC.view.backgroundColor = .clear
        menuPresentationViewController = hostingVC
        present(hostingVC, animated: true)
    }
    #endif
}

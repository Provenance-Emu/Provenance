//
//  PVEmulatoreViewController+Menus.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//

import Foundation
import PVCoreBridge

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
        if (presentedViewController is UIAlertController) && !presentedViewController!.isBeingDismissed {
            dismiss(animated: true) { () -> Void in }
        }
        if (presentedViewController is TVAlertController) && !presentedViewController!.isBeingDismissed {
            dismiss(animated: true) { () -> Void in }
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
            self?.updateLastPlayedTime()
        }
        core.setPauseEmulation(false)
    }

    @objc public func showSpeedMenu() {
        let actionSheet = UIAlertController(title: "Game Speed", message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
        actionSheet.popoverPresentationController?.sourceView = self.navigationItem.titleView ?? self.view
        if let menuButton = menuButton {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton.bounds
        }
        let speeds = GameSpeed.allCases.map { $0.description }
        speeds.enumerated().forEach { idx, title in
            let action = UIAlertAction(title: title, style: .default, handler: { (_: UIAlertAction) -> Void in
                self.enableControllerInput(false)
                self.isShowingMenu = false
                self.core.gameSpeed = GameSpeed(rawValue: idx) ?? .normal
                self.core.setPauseEmulation(false)
            })
            actionSheet.addAction(action)
            if idx == self.core.gameSpeed.rawValue {
                actionSheet.preferredAction = action
            }
        }
        let action = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { (_: UIAlertAction) -> Void in
            self.enableControllerInput(false)
            self.isShowingMenu = false
            self.core.setPauseEmulation(false)
        })
        actionSheet.addAction(action)
        present(actionSheet, animated: true, completion: { () -> Void in
            Task.detached { @MainActor in
                await PVControllerManager.shared.iCadeController?.refreshListener()
            }
        })
    }

    public func showMoreInfo() {
        guard let moreInfoViewController = UIStoryboard(name: "Provenance", bundle: BundleLoader.module).instantiateViewController(withIdentifier: "gameMoreInfoVC") as? PVGameMoreInfoViewController else { return }
        moreInfoViewController.game = self.game
        moreInfoViewController.showsPlayButton = false
        let newNav = UINavigationController(rootViewController: moreInfoViewController)

#if os(iOS)
        moreInfoViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.hideMoreInfo))
#else
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.hideMoreInfo))
        tap.allowedPressTypes = [.menu]
        moreInfoViewController.view.addGestureRecognizer(tap)
#endif

        // disable iOS 13 swipe to dismiss...
        newNav.isModalInPresentation = true

        self.present(newNav, animated: true) { () -> Void in }
        // hideMoreInfo will/should do this!
        // self.isShowingMenu = false
        // self.enableControllerInput(false)
    }
}

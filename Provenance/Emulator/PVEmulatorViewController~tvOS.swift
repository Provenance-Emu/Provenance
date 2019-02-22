//
//  PVEmulatorViewController~tvOS.swift
//  ProvenanceTV
//
//  Created by Joseph Mattiello on 7/20/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
import UIKit

extension PVEmulatorViewController {
    @objc func showMenu(_: Any?) {
        enableContorllerInput(true)
        core.setPauseEmulation(true)
        isShowingMenu = true
        let actionsheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if traitCollection.userInterfaceIdiom == .pad {
            actionsheet.popoverPresentationController?.sourceView = menuButton
            actionsheet.popoverPresentationController?.sourceRect = menuButton!.bounds
        }

        if PVControllerManager.shared.iCadeController != nil {
            actionsheet.addAction(UIAlertAction(title: "Disconnect iCade", style: .default, handler: { (_: UIAlertAction) -> Void in
                NotificationCenter.default.post(name: .GCControllerDidDisconnect, object: PVControllerManager.shared.iCadeController)
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }))
        }

        //		if let optionCore = core as? CoreOptional {
        if core is CoreOptional {
            actionsheet.addAction(UIAlertAction(title: "Core Options", style: .default, handler: { _ in
                self.showCoreOptions()
            }))
        }

        let controllerManager = PVControllerManager.shared
        let wantsStartSelectInMenu: Bool = PVEmulatorConfiguration.systemIDWantsStartAndSelectInMenu(game.system.identifier)
        var hideP1MenuActions = false
        if let player1 = controllerManager.player1 {
            #if os(iOS)
                if PVSettingsModel.shared.missingButtonsAlwaysOn {
                    hideP1MenuActions = true
                }
            #endif
            if player1.extendedGamepad != nil || wantsStartSelectInMenu, !hideP1MenuActions {
                // left trigger bound to Start
                // right trigger bound to Select
                actionsheet.addAction(UIAlertAction(title: "P1 Start", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
                actionsheet.addAction(UIAlertAction(title: "P1 Select", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
            }
            if player1.extendedGamepad != nil || wantsStartSelectInMenu {
                actionsheet.addAction(UIAlertAction(title: "P1 AnalogMode", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressAnalogMode(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseAnalogMode(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
            }
        }
        if let player2 = controllerManager.player2 {
            if player2.extendedGamepad != nil || wantsStartSelectInMenu {
                actionsheet.addAction(UIAlertAction(title: "P2 Start", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
                actionsheet.addAction(UIAlertAction(title: "P2 Select", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
                actionsheet.addAction(UIAlertAction(title: "P2 AnalogMode", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressAnalogMode(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseAnalogMode(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
            }
        }
        if let swappableCore = core as? DiscSwappable, swappableCore.currentGameSupportsMultipleDiscs {
            actionsheet.addAction(UIAlertAction(title: "Swap Disc", style: .default, handler: { (_: UIAlertAction) -> Void in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    self.showSwapDiscsMenu()
                })
            }))
        }

        if let actionableCore = core as? CoreActions, let actions = actionableCore.coreActions {
            actions.forEach { coreAction in
                actionsheet.addAction(UIAlertAction(title: coreAction.title, style: .default, handler: { (_: UIAlertAction) -> Void in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        actionableCore.selected(action: coreAction)
                        self.core.setPauseEmulation(false)
                        if coreAction.requiresReset {
                            self.core.resetEmulation()
                        }
                        self.isShowingMenu = false
                        self.enableContorllerInput(false)
                    })
                }))
            }
        }
        #if os(iOS)
            actionsheet.addAction(UIAlertAction(title: "Save Screenshot", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.perform(#selector(self.takeScreenshot), with: nil, afterDelay: 0.1)
            }))
        #endif
        actionsheet.addAction(UIAlertAction(title: "Game Info", style: .default, handler: { (_: UIAlertAction) -> Void in
            let sb = UIStoryboard(name: "Provenance", bundle: nil)
            let moreInfoViewContrller = sb.instantiateViewController(withIdentifier: "gameMoreInfoVC") as? PVGameMoreInfoViewController
            moreInfoViewContrller?.game = self.game
            moreInfoViewContrller?.showsPlayButton = false
            moreInfoViewContrller?.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.hideModeInfo))
            let newNav = UINavigationController(rootViewController: moreInfoViewContrller ?? UIViewController())
            self.present(newNav, animated: true) { () -> Void in }
            self.isShowingMenu = false
            self.enableContorllerInput(false)
        }))
        actionsheet.addAction(UIAlertAction(title: "Game Speed", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.perform(#selector(self.showSpeedMenu), with: nil, afterDelay: 0.1)
        }))
        if core.supportsSaveStates {
            actionsheet.addAction(UIAlertAction(title: "Save States", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.perform(#selector(self.showSaveStateMenu), with: nil, afterDelay: 0.1)
            }))
        }
        actionsheet.addAction(UIAlertAction(title: "Reset", style: .default, handler: { (_: UIAlertAction) -> Void in
            let completion = {
                self.core.setPauseEmulation(false)
                self.core.resetEmulation()
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }

            if PVSettingsModel.shared.autoSave, self.core.supportsSaveStates {
                self.autoSaveState { result in
                    switch result {
                    case .success:
                        break
                    case let .error(error):
                        ELOG("Auto-save failed \(error.localizedDescription)")
                    }
                    completion()
                }
            } else {
                completion()
            }
        }))

        let lastPlayed = game.lastPlayed ?? Date()
        var shouldSave = PVSettingsModel.shared.autoSave
        shouldSave = shouldSave && abs(lastPlayed.timeIntervalSinceNow) > minimumPlayTimeToMakeAutosave
        shouldSave = shouldSave && (game.lastAutosaveAge ?? minutes(2)) > minutes(1)
        shouldSave = shouldSave && abs(game.saveStates.sorted(byKeyPath: "date", ascending: true).last?.date.timeIntervalSinceNow ?? minutes(2)) > minutes(1)

        // Add Non-Saving quit first
        let quitTitle = shouldSave ? "Quit (without save)" : "Quit"
        actionsheet.addAction(UIAlertAction(title: quitTitle, style: shouldSave ? .default : .destructive, handler: { (_: UIAlertAction) -> Void in
            self.quit(optionallySave: false)
        }))

        // If save and quit is an option, add it last with different style
        if shouldSave {
            actionsheet.addAction(UIAlertAction(title: "Save & Quit", style: .destructive, handler: { (_: UIAlertAction) -> Void in
                self.quit(optionallySave: true)
            }))
        }

        let resumeAction = UIAlertAction(title: "Resume", style: .cancel, handler: { (_: UIAlertAction) -> Void in
            self.core.setPauseEmulation(false)
            self.isShowingMenu = false
            self.enableContorllerInput(false)
        })
        actionsheet.addAction(resumeAction)
        if #available(iOS 9.0, *) {
            actionsheet.preferredAction = resumeAction
        }
        present(actionsheet, animated: true, completion: { () -> Void in
            PVControllerManager.shared.iCadeController?.refreshListener()
        })
    }
}

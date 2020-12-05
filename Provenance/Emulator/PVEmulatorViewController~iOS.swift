//
//  PVEmulatorViewController~iOS.swift
//  Provenance
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
        
        let actionSheet = UIAlertController(title: "Game Options", message: nil, preferredStyle: .actionSheet)
        
        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton!.bounds
        }

        if PVControllerManager.shared.iCadeController != nil {
            actionSheet.addAction(UIAlertAction(title: "Disconnect iCade", style: .default, handler: { action in
                NotificationCenter.default.post(name: .GCControllerDidDisconnect, object: PVControllerManager.shared.iCadeController)
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }))
        }

        if core is CoreOptional {
            actionSheet.addAction(UIAlertAction(title: "Core Options", style: .default, handler: { action in
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
                actionSheet.addAction(UIAlertAction(title: "P1 Start", style: .default, handler: { action in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
                actionSheet.addAction(UIAlertAction(title: "P1 Select", style: .default, handler: { action in
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
                actionSheet.addAction(UIAlertAction(title: "P1 Analog Mode", style: .default, handler: { action in
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
                actionSheet.addAction(UIAlertAction(title: "P2 Start", style: .default, handler: { action in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
                actionSheet.addAction(UIAlertAction(title: "P2 Select", style: .default, handler: { action in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
                actionSheet.addAction(UIAlertAction(title: "P2 Analog Mode", style: .default, handler: { action in
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
            actionSheet.addAction(UIAlertAction(title: "Swap Disc", style: .default, handler: { action in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    self.showSwapDiscsMenu()
                })
            }))
        }

        if let actionableCore = core as? CoreActions, let actions = actionableCore.coreActions {
            actions.forEach { coreAction in
                actionSheet.addAction(UIAlertAction(title: coreAction.title, style: .destructive, handler: { action in
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
            actionSheet.addAction(UIAlertAction(title: "Save Screenshot", style: .default, handler: { action in
                self.perform(#selector(self.takeScreenshot), with: nil, afterDelay: 0.1)
            }))
        #endif
        actionSheet.addAction(UIAlertAction(title: "Game Info", style: .default, handler: { action in
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
        actionSheet.addAction(UIAlertAction(title: "Game Speed", style: .default, handler: { action in
            self.perform(#selector(self.showSpeedMenu), with: nil, afterDelay: 0.1)
        }))
        if core.supportsSaveStates {
            actionSheet.addAction(UIAlertAction(title: "Save States", style: .default, handler: { action in
                self.perform(#selector(self.showSaveStateMenu), with: nil, afterDelay: 0.1)
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            if PVSettingsModel.shared.autoSave, self.core.supportsSaveStates {
                self.autoSaveState { result in
                    switch result {
                    case .success:
                        break
                    case let .error(error):
                        ELOG("Auto-save failed \(error.localizedDescription)")
                    }
                }
            }
            self.core.setPauseEmulation(false)
            self.core.resetEmulation()
            self.isShowingMenu = false
            self.enableContorllerInput(false)
        }))

        let lastPlayed = game.lastPlayed ?? Date()
        var shouldSave = PVSettingsModel.shared.autoSave
        shouldSave = shouldSave && abs(lastPlayed.timeIntervalSinceNow) > minimumPlayTimeToMakeAutosave
        shouldSave = shouldSave && (game.lastAutosaveAge ?? minutes(2)) > minutes(1)
        shouldSave = shouldSave && abs(game.saveStates.sorted(byKeyPath: "date", ascending: true).last?.date.timeIntervalSinceNow ?? minutes(2)) > minutes(1)

        // Add Non-Saving quit first
        let quitTitle = shouldSave ? "Quit (without saving)" : "Quit"
        actionSheet.addAction(UIAlertAction(title: quitTitle, style: .destructive, handler: { action in
            self.quit(optionallySave: false)
        }))

        // If save and quit is an option, add it last with different style
        if shouldSave {
            actionSheet.addAction(UIAlertAction(title: "Save & Quit", style: .destructive, handler: { action in
                self.quit(optionallySave: true)
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Resume", style: .default, handler: { action in
            actionSheet.dismiss(animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.enableContorllerInput(false)
                }
            }
        }))

        if actionSheet.isBeingDismissed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }
        }

        present(actionSheet, animated: true, completion: { () -> Void in
            PVControllerManager.shared.iCadeController?.refreshListener()
        })
    }

    //	override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
    //		super.dismiss(animated: flag, completion: completion)
    //	}
}

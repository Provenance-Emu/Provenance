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
    @objc func showMenu(_ sender: AnyObject?) {
        if (!core.isOn) {
            return;
        }
        enableControllerInput(true)
        core.setPauseEmulation(true)
        isShowingMenu = true

        let actionSheet = UIAlertController(title: "Game Options", message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem

#if targetEnvironment(macCatalyst) || os(macOS)
        if let menuButton = menuButton, sender === menuButton {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton.bounds
        } else {
            actionSheet.popoverPresentationController?.sourceView = self.view
            actionSheet.popoverPresentationController?.sourceRect = self.view.bounds
        }
#else
        if let menuButton = menuButton {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton.bounds
        }
#endif

        if PVControllerManager.shared.iCadeController != nil {
            actionSheet.addAction(UIAlertAction(title: "Disconnect iCade", style: .default, handler: { action in
                NotificationCenter.default.post(name: .GCControllerDidDisconnect, object: PVControllerManager.shared.iCadeController)
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableControllerInput(false)
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
        if let player1: GCController = controllerManager.player1 {
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
                    self.enableControllerInput(false)
                }))
                actionSheet.addAction(UIAlertAction(title: "P1 Select", style: .default, handler: { action in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 0)
                    })
                    self.enableControllerInput(false)
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
                    self.enableControllerInput(false)
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
                    self.enableControllerInput(false)
                }))
                actionSheet.addAction(UIAlertAction(title: "P2 Select", style: .default, handler: { action in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 1)
                    })
                    self.enableControllerInput(false)
                }))
                actionSheet.addAction(UIAlertAction(title: "P2 Analog Mode", style: .default, handler: { action in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressAnalogMode(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseAnalogMode(forPlayer: 1)
                    })
                    self.enableControllerInput(false)
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
                actionSheet.addAction(UIAlertAction(title: coreAction.title, style: coreAction.style, handler: { action in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        actionableCore.selected(action: coreAction)
                        self.core.setPauseEmulation(false)
                        if coreAction.requiresReset {
                            self.core.resetEmulation()
                        }
                        self.isShowingMenu = false
                        self.enableControllerInput(false)
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
            self.showMoreInfo()
        }))
        actionSheet.addAction(UIAlertAction(title: "Game Speed", style: .default, handler: { action in
            self.perform(#selector(self.showSpeedMenu(_:)), with: sender, afterDelay: 0.1)
        }))
        if core.supportsSaveStates {
            actionSheet.addAction(UIAlertAction(title: "Save States", style: .default, handler: { action in
                self.perform(#selector(self.showSaveStateMenu), with: nil, afterDelay: 0.1)
            }))
        }
        if let gameWithCheat = core as? GameWithCheat,
           gameWithCheat.supportsCheatCode {
            actionSheet.addAction(UIAlertAction(title: "Cheat Codes", style: .default, handler: { action in
                self.perform(#selector(self.showCheatsMenu), with: nil, afterDelay: 0.1)
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            let completion = {
                self.core.setPauseEmulation(false)
                self.core.resetEmulation()
                self.isShowingMenu = false
                self.enableControllerInput(false)
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
        shouldSave = shouldSave && self.core.supportsSaveStates

            // Add Non-Saving quit first
        let quitTitle = shouldSave ? "Quit (without saving)" : "Quit"
        actionSheet.addAction(UIAlertAction(title: quitTitle, style: .destructive, handler: {[weak self] action in
            guard let self = self else { return }
            self.quit(optionallySave: false)
        }))

            // If save and quit is an option, add it last with different style
        if shouldSave {
            actionSheet.addAction(UIAlertAction(title: "Save & Quit", style: .destructive, handler: {[weak self] action in
                guard let self = self else { return }
                let image = self.captureScreenshot()
                self.createNewSaveState(auto: true, screenshot: image) { result in
                    switch result {
                    case .success:
                        sleep(3);
                        self.quit(optionallySave: false)
                        break
                    case let .error(error):
                        ELOG("Autosave timer failed to make save state: \(error.localizedDescription)")
                    }
                }
            }))
        }

        // make sure this item is marked .cancel so it will be called even if user dismises popup
        let resumeAction = UIAlertAction(title: "Resume", style: .cancel, handler: { action in
            if let appDelegate = UIApplication.shared as? PVApplication,
               appDelegate.isInBackground {
                return // don't resume if in background
            }

            self.core.setPauseEmulation(false)
            self.isShowingMenu = false
            self.enableControllerInput(false)
        })
        actionSheet.addAction(resumeAction)
        actionSheet.preferredAction = resumeAction

        present(actionSheet, animated: true, completion: { () -> Void in
            PVControllerManager.shared.iCadeController?.refreshListener()
        })
    }
}

//
//  GameLaunchingViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit
// import RealmSwift

/*
 Protocol with default implimentation.
 
 This allows any UIViewController class to just inherit GameLaunchingViewController, and then it can call load(PVGame)!
 
 */

public protocol GameLaunchingViewController: class {
    var mustRefreshDataSource: Bool {get set}
    func canLoad(_ game: PVGame) throws
	func load(_ game: PVGame, sender : Any?, core: PVCore?, saveState: PVSaveState?)
	func openSaveState(_ saveState: PVSaveState)
    func updateRecentGames(_ game: PVGame)
    func register3DTouchShortcuts()
	func presentCoreSelection(forGame game : PVGame, sender : Any?)
}

public enum GameLaunchingError: Error {
    case systemNotFound
    case generic(String)
    case missingBIOSes([String])
}

class TextFieldEditBlocker : NSObject, UITextFieldDelegate {
	var didSetConstraints = false

	var switchControl : UISwitch? {
		didSet {
			didSetConstraints = false
		}
	}

	// Prevent selection
	func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
		// Get rid of border
		textField.superview?.backgroundColor = textField.backgroundColor

		// Fix the switches frame from being below center
		if #available(iOS 9.0, *) {
			if !didSetConstraints, let switchControl = switchControl {
				switchControl.constraints.forEach {
					if $0.firstAttribute == .height {
						switchControl.removeConstraint($0)
					}
				}

				switchControl.heightAnchor.constraint(equalTo: textField.heightAnchor, constant: -4).isActive = true
				let centerAnchor = switchControl.centerYAnchor.constraint(equalTo: textField.centerYAnchor, constant: 0)
				centerAnchor.priority = .defaultHigh + 1
				centerAnchor.isActive = true

				textField.constraints.forEach {
					if $0.firstAttribute == .height {
						$0.constant += 20
					}
				}

				didSetConstraints = true
			}
		}

		return false
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		return false
	}

	func textFieldDidBeginEditing(_ textField: UITextField) {
		textField.resignFirstResponder()
	}
}

// Need a strong reference, so making static
let textEditBlocker = TextFieldEditBlocker()

extension GameLaunchingViewController where Self : UIViewController {

    private func biosCheck(system: PVSystem) throws {
        guard system.requiresBIOS else {
            // Nothing to do
            return
        }

        // Check if requires a BIOS and has them all - only warns if md5's mismatch
        let biosEntries = system.bioses
        guard !biosEntries.isEmpty  else {
            ELOG("System \(system.name) specifies it requires BIOS files but does not provide values for \(SystemDictionaryKeys.BIOSEntries)")
            throw GameLaunchingError.generic("Invalid configuration for system \(system.name). Missing BIOS dictionary in systems.plist")
        }

        let biosPathContents: [String]
        do {
			#if swift(>=4.1)
			biosPathContents = try FileManager.default.contentsOfDirectory(at: system.biosDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]).compactMap { $0.isFileURL ? $0.lastPathComponent : nil }
			#else
            biosPathContents = try FileManager.default.contentsOfDirectory(at: system.biosDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]).flatMap { $0.isFileURL ? $0.lastPathComponent : nil }
			#endif
        } catch {
            try? FileManager.default.createDirectory(at: system.biosDirectory, withIntermediateDirectories: true, attributes: nil)
            let biosFiles = biosEntries.map { return $0.expectedFilename }.joined(separator: ", ")

            let documentsPath = PVEmulatorConfiguration.documentsPath.path
            let biosDirectory  = system.biosDirectory.path.replacingOccurrences(of: documentsPath, with: "")

            let message = "This system requires BIOS files. Please upload '\(biosFiles)' to \(biosDirectory)."
            ELOG(message)
            throw GameLaunchingError.generic(message)
        }

        // Store the HASH : FILENAME of the BIOS directory contents
        // Only generated if needed for matching if filename fails
        var biosPathContentsMD5Cache: [String: String]?

        var missingBIOSES = [String]()

        // Go through each BIOSEntry struct and see if all non-optional BIOS's were found in the BIOS dir
        // Try to match MD5s for files that don't match by name, and rename them to what's expected if found
        // Warn on files that have filename match but MD5 doesn't match expected
        let canLoad = biosEntries.all {

            // Check for a direct filename match and that it isn't an optional BIOS if we don't find it
            if !biosPathContents.contains($0.expectedFilename) && !$0.optional {
                // Didn't match by files name, now we generate all the md5's and see if any match, if they do, move the matching file to the correct filename

                // 1 - Lazily generate the hashes of files in the BIOS directory
                if biosPathContentsMD5Cache == nil {
                    biosPathContentsMD5Cache = biosPathContents.reduce([String:String](), { (hashDictionary, filename) -> [String: String] in
                        let fullBIOSFileURL = system.biosDirectory.appendingPathComponent(filename, isDirectory: false)
                        if let hash = FileManager.default.md5ForFile(atPath: fullBIOSFileURL.path, fromOffset: 0), !hash.isEmpty {
                            // Make mutable
                            var hashDictionary = hashDictionary
                            hashDictionary[hash] = filename
                            return hashDictionary
                        } else {
                            // Couldn't hash for whatever reason, just pass on the hash dict
                            return hashDictionary
                        }
                    })
                }

                // 2 - See if any hashes in the BIOS directory match the current BIOS entry we're investigating.
                if let biosPathContentsMD5Cache = biosPathContentsMD5Cache, let filenameOfFoundFile = biosPathContentsMD5Cache[$0.expectedMD5.uppercased()] {
                    // Rename the file to what we expected
                    do {
                        let from = system.biosDirectory.appendingPathComponent(filenameOfFoundFile, isDirectory: false)
                        let to = system.biosDirectory.appendingPathComponent($0.expectedFilename, isDirectory: false)
                        try FileManager.default.moveItem(at: from, to: to)
                        // Succesfully move the file, mark this BIOSEntry as true in the .all{} loop
                        ILOG("Rename file \(filenameOfFoundFile) to \($0.expectedFilename) because it matched by MD5 \($0.expectedMD5)")
                        return true
                    } catch {
                        ELOG("Failed to rename \(filenameOfFoundFile) to \($0.expectedFilename)\n\(error.localizedDescription)")
                        // Since we couldn't rename, mark this as a false
                        missingBIOSES.append($0.expectedFilename)
                        return false
                    }
                } else {
                    // No MD5 matches either
                    missingBIOSES.append($0.expectedFilename)
                    return false
                }
            } else {
                // Not as important, but log if MD5 is mismatched.
                // Cores care about filenames for some reason, not MD5s
                let fileMD5 = FileManager.default.md5ForFile(atPath: system.biosDirectory.appendingPathComponent($0.expectedFilename, isDirectory: false).path, fromOffset: 0) ?? ""
                if fileMD5 != $0.expectedMD5.uppercased() {
                    WLOG("MD5 hash for \($0.expectedFilename) didn't match the expected value.\nGot {\(fileMD5)} expected {\($0.expectedMD5.uppercased())}")
                }
                return true
            }
        } // End canLoad .all loop

        if !canLoad {
            throw GameLaunchingError.missingBIOSes(missingBIOSES)
        }
    }

    func canLoad(_ game: PVGame) throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try biosCheck(system: system)
    }

    private func displayAndLogError(withTitle title: String, message: String) {
        ELOG(message)

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertController, animated: true)
    }

	func presentCoreSelection(forGame game : PVGame, sender: Any?) {
		guard let system = game.system else {
			ELOG("No sytem for game \(game.title)")
			return
		}

		let cores = system.cores

		let coreChoiceAlert = UIAlertController(title: "Multiple cores found", message: "Select which core to use with this game", preferredStyle: .actionSheet)
		if traitCollection.userInterfaceIdiom == .pad, let senderView = sender as? UIView ?? self.view {
			coreChoiceAlert.popoverPresentationController?.sourceView = senderView
			coreChoiceAlert.popoverPresentationController?.sourceRect = senderView.bounds
		}

		for core in cores {
			let action = UIAlertAction(title: core.projectName, style: .default) {[unowned self] (action) in
				let alwaysUseAlert = UIAlertController(title: nil, message: "Open with \(core.projectName)...", preferredStyle: .actionSheet)
				if self.traitCollection.userInterfaceIdiom == .pad, let senderView = sender as? UIView ?? self.view {
					alwaysUseAlert.popoverPresentationController?.sourceView = senderView
					alwaysUseAlert.popoverPresentationController?.sourceRect = senderView.bounds
				}

				let thisTimeOnlyAction = UIAlertAction(title: "This time", style: .default, handler: {action in self.presentEMU(withCore: core, forGame: game)})
				let alwaysThisGameAction = UIAlertAction(title: "Always for this game", style: .default, handler: {[unowned self] action in
					try! RomDatabase.sharedInstance.writeTransaction {
						game.userPreferredCoreID = core.identifier
					}
					self.presentEMU(withCore: core, forGame: game)

				})
				let alwaysThisSytemAction = UIAlertAction(title: "Always for this system", style: .default, handler: {[unowned self] action in
					try! RomDatabase.sharedInstance.writeTransaction {
						system.userPreferredCoreID = core.identifier
					}
					self.presentEMU(withCore: core, forGame: game)
				})

				alwaysUseAlert.addAction(thisTimeOnlyAction)
				alwaysUseAlert.addAction(alwaysThisGameAction)
				alwaysUseAlert.addAction(alwaysThisSytemAction)

				self.present(alwaysUseAlert, animated: true)
			}

			coreChoiceAlert.addAction(action)
		}

		coreChoiceAlert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))

		present(coreChoiceAlert, animated: true)
	}

	func load(_ game: PVGame, sender : Any?, core: PVCore?, saveState : PVSaveState? = nil) {
        guard !(presentedViewController is PVEmulatorViewController) else {
            let currentGameVC = presentedViewController as! PVEmulatorViewController
            displayAndLogError(withTitle: "Cannot open new game", message: "A game is already running the game \(currentGameVC.game.title).")
            return
        }

        // Pre-flight
        guard let system = game.system else {
            displayAndLogError(withTitle: "Cannot open game", message: "Requested system cannot be found for game '\(game.title)'.")
            return
        }

        do {
            try self.canLoad(game)
            // Init emulator VC

			guard let system = game.system else {
				displayAndLogError(withTitle: "Cannot open game", message: "No system found matching '\(game.systemIdentifier)'.")
				return
			}

			let cores = system.cores

			guard !cores.isEmpty else {
				displayAndLogError(withTitle: "Cannot open game", message: "No core found for game system '\(system.shortName)'.")
				return
			}

			var selectedCore : PVCore?

			// If a core is passed in and it's valid for this system, use it.
			if let saveState = saveState {
				if cores.contains(saveState.core) {
					selectedCore = saveState.core
				} else {
					// TODO: Present Error
				}
			}

			// See if the user chose a core
			if selectedCore == nil, let core = core, cores.contains(core) {
				selectedCore = core
			}

			// Check if multiple cores can launch this rom
			if selectedCore == nil, cores.count > 1 {

				let coresString : String = cores.map({return $0.projectName}).joined(separator: ", ")
				ILOG("Multiple cores found for system \(system.name). Cores: \(coresString)")

				// See if the system or game has a default selection already set
				if let userSelecion = game.userPreferredCoreID ?? system.userPreferredCoreID,
					let chosenCore = cores.first(where: { return $0.identifier == userSelecion }) {
					ILOG("User has already selected core \(chosenCore.projectName) for \(system.shortName)")
					presentEMU(withCore: chosenCore, forGame: game)
					return
				}

				// User has no core preference, present dialogue to pick
				presentCoreSelection(forGame: game, sender: sender)
			} else {
				presentEMU(withCore: selectedCore ?? cores.first!, forGame: game, fromSaveState: saveState)
			}
        } catch GameLaunchingError.missingBIOSes(let missingBIOSes) {
            // Create missing BIOS directory to help user out
            PVEmulatorConfiguration.createBIOSDirectory(forSystemIdentifier: system.enumValue)

            let missingFilesString = missingBIOSes.joined(separator: ", ")
            let relativeBiosPath = "Documents/BIOS/\(system.identifier)/"

            let message = "\(system.shortName) requires BIOS files to run games. Ensure the following files are inside \(relativeBiosPath)\n\(missingFilesString)"
            displayAndLogError(withTitle: "Missing BIOS files", message: message)
        } catch GameLaunchingError.systemNotFound {
            displayAndLogError(withTitle: "Core not found", message: "No Core was found to run system '\(system.name)'.")
        } catch GameLaunchingError.generic(let message) {
            displayAndLogError(withTitle: "Cannot open game", message: message)
        } catch {
            displayAndLogError(withTitle: "Cannot open game", message: "Unknown error: \(error.localizedDescription)")
        }
    }

	private func presentEMU(withCore core : PVCore, forGame game: PVGame, fromSaveState saveState: PVSaveState? = nil) {
		guard let coreInstance = core.createInstance(forSystem: game.system) else {
			displayAndLogError(withTitle: "Cannot open game", message: "Failed to create instance of core '\(core.projectName)'.")
			ELOG("Failed to init core instance")
			return
		}

		let emulatorViewController = PVEmulatorViewController(game: game, core: coreInstance)

		// Configure emulator VC
		// NOTE: These technically could be derived in PVEmulatorViewController directly
		emulatorViewController.batterySavesPath = PVEmulatorConfiguration.batterySavesPath(forGame: game).path
		emulatorViewController.saveStatePath = PVEmulatorConfiguration.saveStatePath(forGame: game).path
		emulatorViewController.BIOSPath = PVEmulatorConfiguration.biosPath(forGame: game).path

		let presentEMUVC : (PVSaveState?)->Void = { saveSate in
			// Present the emulator VC
			emulatorViewController.modalTransitionStyle = .crossDissolve
			self.present(emulatorViewController, animated: true) {() -> Void in
				// Open the save state after a bootup delay if the user selected one
				if let saveState = saveState {
					DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [unowned self] in
						self.openSaveState(saveState)
					})
				}
			}

			PVControllerManager.shared.iCadeController?.refreshListener()

			do {
				try RomDatabase.sharedInstance.writeTransaction {
					game.playCount += 1
					game.lastPlayed = Date()
				}
			} catch {
				ELOG("\(error.localizedDescription)")
			}

			self.updateRecentGames(game)
		}

		// Check if autosave exists
		if saveState == nil {
			checkForAutosaveThenRun(withCore: core, forGame: game) { optionallyChosenSaveState in
				presentEMUVC(optionallyChosenSaveState)
			}
		} else {
			presentEMUVC(saveState)
		}
	}

	private func runEmu(withCore core: PVCore, game: PVGame) {

	}

	private func checkForAutosaveThenRun(withCore core : PVCore, forGame game: PVGame, completion: @escaping (PVSaveState?)->Void) {
		// TODO: This should be moved to when the user goes to open the game, and should check if the game was loaded from an autosave already and not ask
		// WARN: Finish me
		if let latestAutoSave = game.saveStates.filter("isAutosave == true && core.identifier == \"\(core.identifier)\"").sorted(byKeyPath: "date", ascending: false).first {
			let shouldAskToLoadSaveState: Bool = PVSettingsModel.sharedInstance().askToAutoLoad
			let shouldAutoLoadSaveState: Bool = PVSettingsModel.sharedInstance().autoLoadAutoSaves
			if shouldAskToLoadSaveState {

				// Alert to ask about loading an autosave
				let alert = UIAlertController(title: "Autosave file detected", message: "Would you like to load it?", preferredStyle: .alert)

				let switchControl = UISwitch()
				switchControl.isOn = !PVSettingsModel.sharedInstance().askToAutoLoad
				textEditBlocker.switchControl = switchControl

				// 1) No
				alert.addAction(UIAlertAction(title: "No", style: .default, handler: { (_ action: UIAlertAction) -> Void in
					if switchControl.isOn {
                        PVSettingsModel.sharedInstance().askToAutoLoad     = false
                        PVSettingsModel.sharedInstance().autoLoadAutoSaves = false
					}
					completion(nil)
				}))

				// 2) Yes
				alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_ action: UIAlertAction) -> Void in
					if switchControl.isOn {
						PVSettingsModel.sharedInstance().askToAutoLoad     = false
						PVSettingsModel.sharedInstance().autoLoadAutoSaves = true
					}
					completion(latestAutoSave)
				}))

				// 3) Add a save this setting toggle
				alert.addTextField { (textField) in
					textField.text = "Remember my selection"
					textField.backgroundColor = Theme.currentTheme.settingsCellBackground
					textField.textColor = Theme.currentTheme.settingsCellText
					textField.tintColor = Theme.currentTheme.settingsCellBackground
					textField.rightViewMode = .always
					textField.rightView = switchControl
					textField.borderStyle = .none

					textField.layer.borderColor = Theme.currentTheme.settingsCellBackground!.cgColor
					textField.delegate = textEditBlocker // Weak ref

					switchControl.translatesAutoresizingMaskIntoConstraints = false

//					switchControl.bounds.size.height = textField.bounds.height
					switchControl.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
				}

				// 4) Never
//				alert.addAction(UIAlertAction(title: "No, never and stop asking", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//					completion(nil)
//					PVSettingsModel.sharedInstance().askToAutoLoad = false
//					PVSettingsModel.sharedInstance().autoLoadAutoSaves = false
//				}))

				// Present the alert
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {() -> Void in
					self.present(alert, animated: true) {() -> Void in }
				})

			} else if shouldAutoLoadSaveState {
				completion(latestAutoSave)
			}
		} else {
			completion(nil)
		}
	}

    func doLoad(_ game: PVGame) throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try biosCheck(system: system)
    }

    func updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.sharedInstance
        database.refresh()

        let recents: Results<PVRecentGame> = database.all(PVRecentGame.self)

        let recentsMatchingGame =  database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash)
        let recentToDelete = recentsMatchingGame.first
        if let recentToDelete = recentToDelete {
            do {
                try database.delete(recentToDelete)
            } catch {
                ELOG("Failed to delete recent: \(error.localizedDescription)")
            }
        }

        if recents.count >= PVMaxRecentsCount() {
            // TODO: This should delete more than just the last incase we had an overflow earlier
            if let oldestRecent: PVRecentGame = recents.sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false).last {
                do {
                    try database.delete(oldestRecent)
                } catch {
                    ELOG("Failed to delete recent: \(error.localizedDescription)")
                }
            }
        }

        if let currentRecent = game.recentPlays.first {
            do {
                currentRecent.lastPlayedDate = Date()
                try database.add(currentRecent, update: true)
            } catch {
                ELOG("Failed to update Recent Game entry. \(error.localizedDescription)")
            }
        } else {
            let newRecent = PVRecentGame(withGame: game)
            do {
                try database.add(newRecent, update: false)

                let activity = game.spotlightActivity
                // Make active, causes it to index also
                self.userActivity = activity
            } catch {
                ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
            }
        }

        register3DTouchShortcuts()
    }

	func openSaveState(_ saveState: PVSaveState) {
		if let gameVC = presentedViewController as? PVEmulatorViewController {

			try? RomDatabase.sharedInstance.writeTransaction {
				saveState.lastOpened = Date()
			}

			gameVC.core.setPauseEmulation(true)
			gameVC.core.loadStateFromFile(atPath: saveState.file.url.path)
			gameVC.core.setPauseEmulation(false)
		} else {
			presentWarning("No core loaded")
		}
	}

    func register3DTouchShortcuts() {
        if #available(iOS 9.0, *) {
            #if os(iOS)
                // Add 3D touch shortcuts to recent games
                var shortcuts = [UIApplicationShortcutItem]()

                let database = RomDatabase.sharedInstance

                let favorites = database.all(PVGame.self, where: #keyPath(PVGame.isFavorite), value: true)
                for game in favorites {
                    let icon: UIApplicationShortcutIcon?
                    if #available(iOS 9.1, *) {
                        icon  = UIApplicationShortcutIcon(type: .favorite)
                    } else {
                        icon = UIApplicationShortcutIcon(type: .play)
                    }

                    let shortcut = UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: game.title, localizedSubtitle: PVEmulatorConfiguration.name(forSystemIdentifier: game.systemIdentifier), icon: icon, userInfo: ["PVGameHash": game.md5Hash])
                    shortcuts.append(shortcut)
                }

                let sortedRecents: Results<PVRecentGame> = database.all(PVRecentGame.self).sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)

                for recentGame in sortedRecents {
                    if let game = recentGame.game {

                        let icon: UIApplicationShortcutIcon?
                        icon = UIApplicationShortcutIcon(type: .play)

                        let shortcut = UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: game.title, localizedSubtitle: PVEmulatorConfiguration.name(forSystemIdentifier: game.systemIdentifier), icon: icon, userInfo: ["PVGameHash": game.md5Hash])
                        shortcuts.append(shortcut)
                    }
                }

                UIApplication.shared.shortcutItems = shortcuts
            #endif
        } else {
            // Fallback on earlier versions
        }
    }
}

// TODO: Move me
extension Sequence {
    func any(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        return try self.contains(where: { try predicate($0) == true })
    }

    func all(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        let containsFailed = try self.contains(where: { try predicate($0) == false })
        return !containsFailed
    }

    func none(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        let result = try self.any(predicate)
        return !result
    }

    func count(_ predicate: (Element) throws -> Bool) rethrows -> Int {
        return try self.reduce(0, { (result, element) in
            return result + (try predicate(element) ? 1 : 0)
        })
    }
}

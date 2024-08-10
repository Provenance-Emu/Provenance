//
//  GameLaunchingViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import RealmSwift
import UIKit
import ZipArchive
#if canImport(MBProgressHUD)
import MBProgressHUD
#endif
import AsyncAlgorithms
import PVSettings

private let WIKI_BIOS_URL = "https://wiki.provenance-emu.com/installation-and-usage/bios-requirements"

public func PVMaxRecentsCount() -> Int {
    #if os(tvOS)
        return 12
    #elseif os(iOS)
        #if EXTENSION
            return 9
        #else
    return UIApplication.shared.windows.first { $0.isKeyWindow }?.traitCollection.userInterfaceIdiom == .phone ? 6 : 9
        #endif
    #endif
}

/*
 Protocol with default implimentation.

 This allows any UIViewController class to just inherit GameLaunchingViewController, and then it can call load(PVGame)!

 */

public protocol GameLaunchingViewController: AnyObject {
    func canLoad(_ game: PVGame) async throws
    func load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async
    func openSaveState(_ saveState: PVSaveState)
    func updateRecentGames(_ game: PVGame)
    func presentCoreSelection(forGame game: PVGame, sender: Any?)
}

public protocol GameSharingViewController: AnyObject {
    func share(for game: PVGame, sender: Any?) async
}

extension GameSharingViewController where Self: UIViewController {
    func share(for game: PVGame, sender: Any?) async {
        /*
         TODO:
         Add native share action for sharing to other provenance devices
         Add metadata files to shares so they can cleanly re-import
         Well, then also need a way to import save states
         */
        #if !os(tvOS)
            // - Create temporary directory
            let tempDir = NSTemporaryDirectory()
            let tempDirURL = URL(fileURLWithPath: tempDir, isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG("Failed to create temp dir \(tempDir). Error: " + error.localizedDescription)
                return
            }

            let deleteTempDir: () -> Void = {
                do {
                    try FileManager.default.removeItem(at: tempDirURL)
                } catch {
                    ELOG("Failed to delete temp dir: " + error.localizedDescription)
                }
            }

            // - Add save states and images
            // - Use symlinks to images so we can modify the filenames
        var files = await game.saveStates.async.reduce([URL](), { (arr, save) -> [URL] in
            guard await save.file.online else {
                    WLOG("Save file is missing. Can't add to zip")
                    return arr
                }
                var arr = arr
            await arr.append(save.file.url)
            if let image = save.image, await image.online {
                    // Construct destination url "{SAVEFILE}.{EXT}"
                    let destination = await tempDirURL.appendingPathComponent(save.file.fileNameWithoutExtension + "." + image.url.pathExtension, isDirectory: false)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        arr.append(destination)
                    } else {
                        do {
                            try await FileManager.default.createSymbolicLink(at: destination, withDestinationURL: image.url)
                            arr.append(destination)
                        } catch {
                            ELOG("Failed to make symlink: " + error.localizedDescription)
                        }
                    }
                }
                return arr
            })

            let addImageFromCache: (String?, String) -> Void = { imageURL, suffix in
                guard let imageURL = imageURL, !imageURL.isEmpty, PVMediaCache.fileExists(forKey: imageURL) else {
                    return
                }
                if let localURL = PVMediaCache.filePath(forKey: imageURL), FileManager.default.fileExists(atPath: localURL.path) {
                    var originalExtension = (imageURL as NSString).pathExtension
                    if originalExtension.isEmpty {
                        originalExtension = localURL.pathExtension
                    }
                    if originalExtension.isEmpty {
                        originalExtension = "jpg" // now this is just a guess
                    }
                    let destination = tempDirURL.appendingPathComponent(game.title + suffix + "." + originalExtension, isDirectory: false)
                    try? FileManager.default.removeItem(at: destination)
                    do {
                        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: localURL)
                        files.append(destination)
                        ILOG("Added \(suffix) image to zip")
                    } catch {
                        // Add anyway to catch the fact that fileExists doesnt' work for symlinks that already exist
                        ELOG("Failed to make symlink: " + error.localizedDescription)
                    }
                }
            }

            let addImageFromURL: (URL?, String) -> Void = { imageURL, suffix in
                guard let imageURL = imageURL, FileManager.default.fileExists(atPath: imageURL.path) else {
                    return
                }

                let originalExtension = imageURL.pathExtension

                let destination = tempDirURL.appendingPathComponent(game.title + suffix + "." + originalExtension, isDirectory: false)
                try? FileManager.default.removeItem(at: destination)
                do {
                    try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: imageURL)
                    files.append(destination)
                    ILOG("Added \(suffix) image to zip")
                } catch {
                    // Add anyway to catch the fact that fileExists doesnt' work for symlinks that already exist
                    ELOG("Failed to make symlink: " + error.localizedDescription)
                }
            }

            ILOG("Adding \(files.count) save states and their images to zip")
            addImageFromCache(game.originalArtworkURL, "")
            addImageFromCache(game.customArtworkURL, "-Custom")
            addImageFromCache(game.boxBackArtworkURL, "-Back")

            for screenShot in game.screenShots {
                let dateString = PVEmulatorConfiguration.string(fromDate: screenShot.createdDate)
                await addImageFromURL(screenShot.url, "-Screenshot " + dateString)
            }

            // - Add main game file
        await files.append(game.file.url)

            // Check for and add battery saves
        if await FileManager.default.fileExists(atPath: game.batterSavesPath.path), let batterySaves = try? await FileManager.default.contentsOfDirectory(at: game.batterSavesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !batterySaves.isEmpty {
                ILOG("Adding \(batterySaves.count) battery saves to zip")
                files.append(contentsOf: batterySaves)
            }

            let zipPath = tempDirURL.appendingPathComponent("\(game.title)-\(game.system.shortNameAlt ?? game.system.shortName).zip", isDirectory: false)
            let paths: [String] = files.map { $0.path }

        let hud = await MBProgressHUD.showAdded(to: view, animated: true)
            hud.isUserInteractionEnabled = false
            hud.mode = .indeterminate
            hud.label.text = "Creating ZIP"
            hud.detailsLabel.text = "Please be patient, this could take a while…"

            DispatchQueue.global(qos: .background).async {
                let success = SSZipArchive.createZipFile(atPath: zipPath.path, withFilesAtPaths: paths)

                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }

                    hud.hide(animated: true, afterDelay: 0.1)
                    guard success else {
                        deleteTempDir()
                        ELOG("Failed to zip of game files")
                        return
                    }

                    let shareVC = UIActivityViewController(activityItems: [zipPath], applicationActivities: nil)

                    if let anyView = sender as? UIView {
                        shareVC.popoverPresentationController?.sourceView = anyView
                        shareVC.popoverPresentationController?.sourceRect = anyView.convert(anyView.frame, from: self.view)
                    } else if let anyBarButtonItem = sender as? UIBarButtonItem {
                        shareVC.popoverPresentationController?.barButtonItem = anyBarButtonItem
                    } else {
                        shareVC.popoverPresentationController?.sourceView = self.view
                        shareVC.popoverPresentationController?.sourceRect = self.view.bounds
                    }

                    // Executed after share is completed
                    shareVC.completionWithItemsHandler = { (_: UIActivity.ActivityType?, _: Bool, _: [Any]?, _: Error?) in
                        // Cleanup our temp folder
                        deleteTempDir()
                    }

                    if self.isBeingPresented {
                        self.present(shareVC, animated: true)
                    } else {
                        let vc = UIApplication.shared.delegate?.window??.rootViewController
                        vc?.present(shareVC, animated: true)
                    }
                }
            }

        #endif
    }
}

public enum GameLaunchingError: Error {
    case systemNotFound
    case generic(String)
    case missingBIOSes([String])
}

#if os(iOS)
    final class TextFieldEditBlocker: NSObject, UITextFieldDelegate {
        var didSetConstraints = false

        var switchControl: UISwitch? {
            didSet {
                didSetConstraints = false
            }
        }

        // Prevent selection
        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            // Get rid of border
            textField.superview?.backgroundColor = textField.backgroundColor

            // Fix the switches frame from being below center
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

            return false
        }

        func textField(_: UITextField, shouldChangeCharactersIn _: NSRange, replacementString _: String) -> Bool {
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.resignFirstResponder()
        }
    }

    // Need a strong reference, so making static
    let textEditBlocker = TextFieldEditBlocker()
#endif
extension GameLaunchingViewController where Self: UIViewController {

    private func getExpectedFilename(_ bios:BIOS) -> String {
        var expectedFilename=bios.expectedFilename
        if expectedFilename.contains("|") {
            expectedFilename=expectedFilename.components(separatedBy: "|")[0]
        }
        return expectedFilename
    }

    private func biosCheck(system: PVSystem) async throws {
        guard system.requiresBIOS else {
            // Nothing to do
            return
        }

        // Check if requires a BIOS and has them all - only warns if md5's mismatch
        let biosEntries = system.bioses
        guard !biosEntries.isEmpty else {
            ELOG("System \(system.name) specifies it requires BIOS files but does not provide values for \(SystemDictionaryKeys.BIOSEntries)")
            throw GameLaunchingError.generic("Invalid configuration for system \(system.name). Missing BIOS dictionary in systems.plist")
        }

        let biosPathContents: [String]
        do {
            biosPathContents = try await FileManager.default.contentsOfDirectory(at: system.biosDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]).compactMap { $0.isFileURL ? $0.lastPathComponent : nil }
        } catch {
            try? await FileManager.default.createDirectory(at: system.biosDirectory, withIntermediateDirectories: true, attributes: nil)
            let biosFiles = await biosEntries.toArray().asyncMap {
                return await self.getExpectedFilename($0.asDomain())
            }.joined(separator: ", ")

            let documentsPath = PVEmulatorConfiguration.documentsPath.path
            let biosDirectory = await system.biosDirectory.path.replacingOccurrences(of: documentsPath, with: "")

            let message = "This system requires BIOS files. Please upload '\(biosFiles)' to \(biosDirectory)."
            ELOG(message)
            throw GameLaunchingError.generic(message)
        }

        // Store the HASH : FILENAME of the BIOS directory contents
        // Only generated if needed for matching if filename fails
        var biosPathContentsMD5Cache: [String: String]?

        var missingBIOSES = [String]()
        var entries = await biosEntries.toArray().asyncMap({ await $0.asDomain() })
        // Search for additional conditional bios requirements stored as JSON file
        if await FileManager.default.fileExists(atPath: system.biosDirectory.appendingPathComponent("requirements.json").path) {
            let additionalBios=try await LibrarySerializer.retrieve(system.biosDirectory.appendingPathComponent("requirements.json"), as: [String:[String:Int]].self)
            await additionalBios.keys.concurrentForEach({
                file in
                if let biosInfo = additionalBios[file],
                   let md5 = biosInfo.keys.first,
                   let size = biosInfo[md5] {
                    let bios = PVBIOS(withSystem: system, descriptionText: file, expectedMD5: md5, expectedSize: size, expectedFilename: file)
                    bios.optional = false
                    await entries.append(bios.asDomain())
                }
            })
        }

        // Go through each BIOSEntry struct and see if all non-optional BIOS's were found in the BIOS dir
        // Try to match MD5s for files that don't match by name, and rename them to what's expected if found
        // Warn on files that have filename match but MD5 doesn't match expected
        var canLoad = true
        await entries.concurrentForEach {
            let expectedFilename=self.getExpectedFilename($0)
            // Check for a direct filename match and that it isn't an optional BIOS if we don't find it
            if !biosPathContents.contains(expectedFilename), !$0.optional {
                // Didn't match by files name, now we generate all the md5's and see if any match, if they do, move the matching file to the correct filename

                // 1 - Lazily generate the hashes of files in the BIOS directory
                if biosPathContentsMD5Cache == nil {
                    biosPathContentsMD5Cache = await biosPathContents.async.reduce([String: String](), { (hashDictionary, filename) -> [String: String] in
                        let fullBIOSFileURL = await system.biosDirectory.appendingPathComponent(filename, isDirectory: false)
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
                        let from = await system.biosDirectory.appendingPathComponent(filenameOfFoundFile, isDirectory: false)
                        let to = await system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
                        try FileManager.default.moveItem(at: from, to: to)
                        // Succesfully move the file, mark this BIOSEntry as true in the .all{} loop
                        ILOG("Rename file \(filenameOfFoundFile) to \(expectedFilename) because it matched by MD5 \($0.expectedMD5.uppercased())")
                    } catch {
                        ELOG("Failed to rename \(filenameOfFoundFile) to \(expectedFilename)\n\(error.localizedDescription)")
                        // Since we couldn't rename, mark this as a false
                        missingBIOSES.append("\(expectedFilename) (MD5: \($0.expectedMD5))")
                        canLoad = false
                    }
                } else {
                    // No MD5 matches either
                    missingBIOSES.append("\(expectedFilename) (MD5: \($0.expectedMD5))")
                    canLoad = false
                }
            } else {
                // Not as important, but log if MD5 is mismatched.
                // Cores care about filenames for some reason, not MD5s
                let fileMD5 = await FileManager.default.md5ForFile(atPath: system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false).path, fromOffset: 0) ?? ""
                if fileMD5 != $0.expectedMD5.uppercased() {
                    WLOG("MD5 hash for \(expectedFilename) didn't match the expected value.\nGot {\(fileMD5)} expected {\($0.expectedMD5.uppercased())}")
                }
            }
        } // End canLoad .all loop

        if !canLoad {
            throw GameLaunchingError.missingBIOSes(missingBIOSES)
        }
    }

    func canLoad(_ game: PVGame) async throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try await biosCheck(system: system)
    }

    private func displayAndLogError(withTitle title: String, message: String, customActions: [UIAlertAction]? = nil) {
        ELOG(message)

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        customActions?.forEach { alertController.addAction($0) }
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)
    }

    func presentCoreSelection(forGame game: PVGame, sender: Any?) {
        guard let system = game.system else {
            ELOG("No system for game \(game.title)")
            return
        }

        let cores = system.cores
            .sorted(byKeyPath: "projectName")
            .filter({
                guard !$0.disabled else {
                    return Defaults[.unsupportedCores]
                }
                guard $0.hasCoreClass else { return false }
                return true
            })
//            .distinct(by: #keyPath(\PVSystem.name))
            .sorted { $0.projectName > $1.projectName }
//            .sorted { $0.supportedSystems.count <= $1.supportedSystems.count }

        let coreChoiceAlert = UIAlertController(title: "Multiple cores found",
                                                message: "Select which core to use with this game. If not sure, select the 1st option.",
                                                preferredStyle: .actionSheet)
#if os(macOS) || targetEnvironment(macCatalyst)
        if let senderView = sender as? UIView ?? self.view {
            coreChoiceAlert.popoverPresentationController?.sourceView = senderView
            coreChoiceAlert.popoverPresentationController?.sourceRect = senderView.bounds
        } else {
            ELOG("Nil senderView")
            assertionFailure("Nil senderview")
        }
#else
        if traitCollection.userInterfaceIdiom == .pad, let senderView = sender as? UIView ?? self.view {
            coreChoiceAlert.popoverPresentationController?.sourceView = senderView
            coreChoiceAlert.popoverPresentationController?.sourceRect = senderView.bounds
        }
#endif

        for core in cores {
            let action = UIAlertAction(title: core.projectName, style: .default) { [unowned self] _ in
                let message = "Open with \(core.projectName)…"
                let alwaysUseAlert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        #if os(macOS) || targetEnvironment(macCatalyst)
                if let senderView = sender as? UIView ?? self.view {
                    alwaysUseAlert.popoverPresentationController?.sourceView = senderView
                    alwaysUseAlert.popoverPresentationController?.sourceRect = senderView.bounds
                } else {
                    ELOG("Nil senderView")
                    assertionFailure("Nil senderview")
                }
        #else
                if self.traitCollection.userInterfaceIdiom == .pad, let senderView = sender as? UIView ?? self.view {
                    alwaysUseAlert.popoverPresentationController?.sourceView = senderView
                    alwaysUseAlert.popoverPresentationController?.sourceRect = senderView.bounds
                }
        #endif

                let thisTimeOnlyAction = UIAlertAction(title: "This time", style: .default, handler: { _ in
                    Task { @MainActor in
                        await self.presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? self.view)
                    }
                })
                let alwaysThisGameAction = UIAlertAction(title: "Always for this game", style: .default, handler: { [unowned self] _ in
                    try! RomDatabase.sharedInstance.writeTransaction {
                        game.userPreferredCoreID = core.identifier
                    }
                    Task { @MainActor in
                        self.presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? self.view)
                    }
                })
                let alwaysThisSystemAction = UIAlertAction(title: "Always for this system", style: .default, handler: { [unowned self] _ in
                    try! RomDatabase.sharedInstance.writeTransaction {
                        system.userPreferredCoreID = core.identifier
                    }
                    self.presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? self.view)
                })

                alwaysUseAlert.addAction(thisTimeOnlyAction)
                alwaysUseAlert.addAction(alwaysThisGameAction)
                alwaysUseAlert.addAction(alwaysThisSystemAction)

                self.present(alwaysUseAlert, animated: true)
            }

            coreChoiceAlert.addAction(action)
        }

        coreChoiceAlert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .destructive, handler: nil))

        present(coreChoiceAlert, animated: true)
    }

//    @MainActor
    func load(_ game: PVGame, sender: Any? = nil, core: PVCore? = nil, saveState: PVSaveState? = nil) async {
        guard await !(presentedViewController is PVEmulatorViewController) else {
            let currentGameVC = await presentedViewController as! PVEmulatorViewController
            displayAndLogError(withTitle: "Cannot open new game", message: "A game is already running the game \(await currentGameVC.game.title).")
            return
        }

        if saveState != nil {
            let path = await saveState!.file.url.path
            ILOG("Opening with save state at path: \(path)")
        }

        // Check if file exists
        if await !game.file.online {
            displayAndLogError(withTitle: "Cannot open game", message: "The ROM file for this game cannot be found. Try re-importing the file for this game.\n\(await game.file.fileName)")
            return
        }

        // Pre-flight
        guard let system = game.system else {
            displayAndLogError(withTitle: "Cannot open game", message: "Requested system cannot be found for game '\(game.title)'.")
            return
        }

        do {
            try await canLoad(game)
            VLOG("canLoad \(game.title)")
            // Init emulator VC

            guard let system = game.system else {
                displayAndLogError(withTitle: "Cannot open game", message: "No system found matching '\(game.systemIdentifier)'.")
                return
            }

            VLOG("\(game.title) matched system \(system.name)\n Cores: \(system.cores.map{$0.principleClass}.joined(separator: ", "))")

            let unsupportedCores = Defaults[.unsupportedCores]
            let cores = system.cores.reduce(into: [], { partialResult, core in
                var partialResult = partialResult
                guard !core.disabled else {
                    ILOG("Filtering core \(core.identifier) as `disabled`, unless `unsupportedCores` == true")
                    if unsupportedCores {
                        partialResult.append(core)
                    }
                }
                guard core.hasCoreClass else {
                    ILOG("Filtering core \(core.identifier) as `.hasCoreClass` == `false`. Class: \(core.principleClass)")
                    return
                }
                partialResult.append(core)
            })

            guard !cores.isEmpty else {
                displayAndLogError(withTitle: "Cannot open game", message: "No core found for game system '\(system.shortName)'.")
                return
            }

            var selectedCore: PVCore?

            // If a core is passed in and it's valid for this system, use it.
            if let saveState = saveState {
                if cores.contains(saveState.core) {
                    selectedCore = saveState.core
                } else {
                    ELOG("Core doesn't match save state system")
                    displayAndLogError(withTitle: "Cannot open game", message: "Available cores does not match core used to save state.")
                    return
                }
            }

            // See if the user chose a core
            if selectedCore == nil, let core = core, cores.contains(core) {
                selectedCore = core
            }

            // Check if multiple cores can launch this rom
            if selectedCore == nil, cores.count > 1 {
                let coresString: String = cores.map({ $0.projectName }).joined(separator: ", ")
                ILOG("Multiple cores found for system \(system.name). Cores: \(coresString)")

                // See if the system or game has a default selection already set
                if let userSelecion = game.userPreferredCoreID ?? system.userPreferredCoreID,
                    let chosenCore = cores.first(where: { $0.identifier == userSelecion }) {
                    ILOG("User has already selected core \(chosenCore.projectName) for \(system.shortName)")
                    let presentingView = await self.view
                    Task { @MainActor in
                        await presentEMU(withCore: chosenCore, forGame: game, source: sender as? UIView ?? presentingView)
                    }
                    return
                }

                // User has no core preference, present dialogue to pick
                presentCoreSelection(forGame: game, sender: sender)
            } else {
                guard let selectedCore = selectedCore ?? cores.first else {
                    displayAndLogError(withTitle: "Cannot open game", message: "No core found.")
                    return
                }
                let presentingView = await self.view
                await presentEMU(withCore: selectedCore, forGame: game, fromSaveState: saveState, source: sender as? UIView ?? presentingView)
//                let contentId : String = "\(system.shortName):\(game.title)"
//                let customAttributes : [String : Any] = ["timeSpent" : game.timeSpentInGame, "md5" : game.md5Hash]
//                Answers.logContentView(withName: "Play ROM",
//                                       contentType: "Gameplay",
//                                       contentId: contentId,
//                                       customAttributes: customAttributes)
            }
        } catch let GameLaunchingError.missingBIOSes(missingBIOSes) {
            // Create missing BIOS directory to help user out
            await PVEmulatorConfiguration.createBIOSDirectory(forSystemIdentifier: system.enumValue)

            let missingFilesString = missingBIOSes.joined(separator: "\n")
            let relativeBiosPath = "Documents/BIOS/\(system.identifier)/"

            let message = "\(system.shortName) requires BIOS files to run games. Ensure the following files are inside \(relativeBiosPath)\n\(missingFilesString)"
            #if os(iOS)
            let guideAction = await UIAlertAction(title: "Guide", style: .default, handler: { _ in
                Task {@MainActor in
                    UIApplication.shared.open(URL(string: WIKI_BIOS_URL)!, options: [:], completionHandler: nil)
                }
                })
                displayAndLogError(withTitle: "Missing BIOS files", message: message, customActions: [guideAction])
            #else
                displayAndLogError(withTitle: "Missing BIOS files", message: message)
            #endif
        } catch GameLaunchingError.systemNotFound {
            displayAndLogError(withTitle: "Core not found", message: "No Core was found to run system '\(system.name)'.")
        } catch let GameLaunchingError.generic(message) {
            displayAndLogError(withTitle: "Cannot open game", message: message)
        } catch {
            displayAndLogError(withTitle: "Cannot open game", message: "Unknown error: \(error.localizedDescription)")
        }
    }

    @MainActor private func presentEMU(withCore core: PVCore, forGame game: PVGame, fromSaveState saveState: PVSaveState? = nil, source: UIView?) async {
        guard let game = RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) else {
            return
        }
        guard let core = RomDatabase.sharedInstance.realm.object(ofType: PVCore.self, forPrimaryKey: core.identifier) else {
            return
        }
        guard let coreInstance = core.createInstance(forSystem: game.system) else {
            displayAndLogError(withTitle: "Cannot open game", message: "Failed to create instance of core '\(core.projectName)'.")
            ELOG("Failed to init core instance")
            return
        }

        let emulatorViewController = PVEmulatorViewController(game: game, core: coreInstance)

        // Check if Save State exists
        if saveState == nil, emulatorViewController.core.supportsSaveStates {
            await checkForSaveStateThenRun(withCore: core, forGame: game, source: source) { optionallyChosenSaveState in
                self.presentEMUVC(emulatorViewController, withGame: game, loadingSaveState: optionallyChosenSaveState)
            }
        } else {
            presentEMUVC(emulatorViewController, withGame: game, loadingSaveState: saveState)
        }
    }

    // Used to just show and then optionally quickly load any passed in PVSaveStates
    @MainActor private func presentEMUVC(_ emulatorViewController: PVEmulatorViewController, withGame game: PVGame, loadingSaveState saveState: PVSaveState? = nil) {
        // Present the emulator VC
        emulatorViewController.modalTransitionStyle = .crossDissolve
        emulatorViewController.modalPresentationStyle = .fullScreen

        present(emulatorViewController, animated: true) { () -> Void in

            emulatorViewController.gpuViewController.screenType = game.system.screenType.rawValue

            // Open the save state after a bootup delay if the user selected one
            // Use a timer loop on ios 10+ to check if the emulator has started running
            if let saveState = saveState {
                emulatorViewController.gpuViewController.view.isHidden = true
                _ = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: {[weak self] timer in
					guard let self = self else {
						timer.invalidate()
						return
					}
                    if !emulatorViewController.core.isEmulationPaused {
                        timer.invalidate()
                        self.openSaveState(saveState)
                        emulatorViewController.gpuViewController.view.isHidden = false
                    }
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
    }

//    @MainActor
    private func checkForSaveStateThenRun(withCore core: PVCore, forGame game: PVGame, source: UIView?, completion: @escaping (PVSaveState?) -> Void) async {
        var foundSave = false
        var saves = game.saveStates.filter("core.identifier == \"\(core.identifier)\"").sorted(byKeyPath: "date", ascending: false).toArray() + game.autoSaves.filter("core.identifier == \"\(core.identifier)\"").sorted(byKeyPath: "date", ascending: false).toArray()
        saves = saves.sorted(by: { $0.date.compare($1.date) == .orderedDescending })

        var saveState : PVSaveState? = await Task {
            for save in saves {
                let path = await save.file.url.path
                if !foundSave && FileManager.default.fileExists(atPath: path) && save.core.identifier == core.identifier {
                    foundSave = true
                    return save
                }
            }
        }.value

        if foundSave, let latestSaveState = saveState {
            let shouldAskToLoadSaveState: Bool = await Defaults[.askToAutoLoad]
            let shouldAutoLoadSaveState: Bool = await Defaults[.autoLoadSaves]

            if shouldAutoLoadSaveState {
                completion(latestSaveState)
            } else if shouldAskToLoadSaveState {
                Task { @MainActor in
                    // 1) Alert to ask about loading latest save state
                    let alert = UIAlertController(title: "Save State Detected", message: nil, preferredStyle: .actionSheet)
                    // TODO: XCode15/iOS17 Requires actual source view here
                    alert.preferredContentSize = CGSize(width: 300, height: 150)
                    alert.popoverPresentationController?.sourceView = source
                    alert.popoverPresentationController?.sourceRect = source?.bounds ?? UIScreen.main.bounds
#if os(iOS)
                    let switchControl = UISwitch()
                    switchControl.isOn = !Defaults[.askToAutoLoad]
                    textEditBlocker.switchControl = switchControl

                    // Add a save this setting toggle
                    alert.addTextField { textField in
                        textField.text = "Auto Load Saves"
                        textField.rightViewMode = .always
                        textField.rightView = switchControl
                        textField.borderStyle = .none
                        textField.delegate = textEditBlocker // Weak ref
                        switchControl.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
                    }
#endif

                    // Restart
                    alert.addAction(UIAlertAction(title: "Restart", style: .default, handler: { (_: UIAlertAction) -> Void in
#if os(iOS)
                        if switchControl.isOn {
                            Defaults[.askToAutoLoad] = false
                            Defaults[.autoLoadSaves] = false
                        }
#endif
                        completion(nil)
                    }))

#if os(tvOS)
                    alert.addAction(UIAlertAction(title: "Restart (Always)", style: .default, handler: { (_: UIAlertAction) -> Void in
                        Defaults[.askToAutoLoad] = false
                        Defaults[.autoLoadSaves] = false
                        completion(nil)
                    }))
#endif

                    // Continue
                    alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (_: UIAlertAction) -> Void in
#if os(iOS)
                        if switchControl.isOn {
                            Defaults[.askToAutoLoad] = false
                            Defaults[.autoLoadSaves] = true
                        }
#endif
                        completion(latestSaveState)
                    }))
                    alert.preferredAction = alert.actions.last

#if os(tvOS)
                    // Continue Always
                    alert.addAction(UIAlertAction(title: "Continue (Always)", style: .default, handler: { (_: UIAlertAction) -> Void in
                        Defaults[.askToAutoLoad] = false
                        Defaults[.autoLoadSaves] = true
                        completion(latestSaveState)
                    }))
#endif

                    alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))

                    // Present the alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let `self` = self else { return }

                        self.present(alert, animated: true)
                    }
                }
            } else {
                // Asking is turned off, either load the save state or don't based on the 'autoLoadSaves' setting
                completion(shouldAutoLoadSaveState ? latestSaveState : nil)
            }
        } else {
            completion(nil)
        }
    }

    func doLoad(_ game: PVGame) async throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try await biosCheck(system: system)
    }

    func updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.sharedInstance
        database.refresh()

        let recents: Results<PVRecentGame> = database.all(PVRecentGame.self)

        let recentsMatchingGame = database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash)
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
            // TODO: Add PVCore
            let newRecent = PVRecentGame(withGame: game)
            do {
                try database.add(newRecent, update: false)

                let activity = game.spotlightActivity
                // Make active, causes it to index also
                userActivity = activity
            } catch {
                ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
            }
        }
    }

    func openSaveState(_ saveState: PVSaveState) {
        if let gameVC = presentedViewController as? PVEmulatorViewController {
            try? RomDatabase.sharedInstance.writeTransaction {
                saveState.lastOpened = Date()
            }

            gameVC.core.setPauseEmulation(true)
            gameVC.core.loadState(fromFileAtPath: saveState.file.url.path) { success, maybeError in
                guard success else {
                    let description = maybeError?.localizedDescription ?? "No reason given"
                    let reason = (maybeError as NSError?)?.localizedFailureReason

                    self.presentError("Failed to load save state: \(description) \(reason ?? "")", source: self.view) {
                        gameVC.core.setPauseEmulation(false)
                    }

                    return
                }

                gameVC.core.setPauseEmulation(false)
            }
        } else {
            presentWarning("No core loaded", source: self.view)
        }
    }
}

// TODO: Move me
extension Sequence {
    func any(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        return try contains(where: { try predicate($0) == true })
    }

    func all(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        let containsFailed = try contains(where: { try predicate($0) == false })
        return !containsFailed
    }

    func none(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        let result = try any(predicate)
        return !result
    }

    func count(_ predicate: (Element) throws -> Bool) rethrows -> Int {
        return try reduce(0, { result, element in
            result + (try predicate(element) ? 1 : 0)
        })
    }
}

//
//  GameSharingViewController+UIKit.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import PVRealm
import PVLogging

#if canImport(UIKit)
import UIKit
#endif

#if canImport(MBProgressHUD)
import MBProgressHUD
#endif

@_exported import PVLibrary

public extension GameSharingViewController where Self: UIViewController {
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
            guard save.file?.online ?? false else {
                WLOG("Save file is missing. Can't add to zip")
                return arr
            }
            var arr = arr
            if let url = save.file?.url {
                arr.append(url)
            }
            if let image = save.image, image.online, let file = save.file {
                // Construct destination url "{SAVEFILE}.{EXT}"
                let destination = tempDirURL.appendingPathComponent(file.fileNameWithoutExtension + "." + (image.url?.pathExtension ?? "raw"), isDirectory: false)
                if FileManager.default.fileExists(atPath: destination.path) {
                    arr.append(destination)
                } else {
                    do {
                        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: image.url!)
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
            addImageFromURL(screenShot.url, "-Screenshot " + dateString)
        }
        
        // - Add main game file
        if let url = game.file?.url {
            files.append(url)
        }
        
        // Check for and add battery saves
        if FileManager.default.fileExists(atPath: game.batterSavesPath.path), let batterySaves = try? await FileManager.default.contentsOfDirectory(at: game.batterSavesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !batterySaves.isEmpty {
            ILOG("Adding \(batterySaves.count) battery saves to zip")
            files.append(contentsOf: batterySaves)
        }
        
        let zipPath = tempDirURL.appendingPathComponent("\(game.title)-\(game.system?.shortNameAlt ?? game.system?.shortName ?? "Unknown").zip", isDirectory: false)
        let paths: [String] = files.map { $0.path }
        
        Task { @MainActor in
            
#if canImport(MBProgressHUD)
            let hud = MBProgressHUD.showAdded(to: view, animated: true)
            hud.isUserInteractionEnabled = false
            hud.mode = .indeterminate
            hud.label.text = "Creating ZIP"
            hud.detailsLabel.text = "Please be patient, this could take a while…"
#endif
            DispatchQueue.global(qos: .background).async {
                let success = SSZipArchive.createZipFile(atPath: zipPath.path, withFilesAtPaths: paths)
                
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }
                    
#if canImport(MBProgressHUD)
                    hud.hide(animated: true, afterDelay: 0.1)
#endif
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
        }
#endif // !os(tvOS)
    }
}

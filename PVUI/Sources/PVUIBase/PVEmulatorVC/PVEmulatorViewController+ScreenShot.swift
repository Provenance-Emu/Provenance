//
//  PVEmulatoreViewController+ScreenShot.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//


// MARK: Screenshot

import UIKit
import Metal
import MetalKit
import GLKit


extension PVEmulatorViewController {
    
    func captureScreenshot() -> UIImage? {
        fpsLabel.alpha = 0.0
        defer { fpsLabel.alpha = 1.0 }
        
        if core.skipLayout && core.touchViewController != nil {
            // For RetroArch cores, find the actual rendering view
            if let metalView = gpuViewController.view.subviews.first(where: { $0 is MTKView }) {
                let size = metalView.frame.size
                UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
                let rec = CGRect(origin: .zero, size: size)
                metalView.drawHierarchy(in: rec, afterScreenUpdates: true)
            } else if let glView = gpuViewController.view.subviews.first(where: { $0 is GLKView }) {
                let size = glView.frame.size
                UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
                let rec = CGRect(origin: .zero, size: size)
                glView.drawHierarchy(in: rec, afterScreenUpdates: true)
            } else {
                // Fallback to capturing the GPU view directly
                let size = gpuViewController.view.frame.size
                UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
                let rec = CGRect(origin: .zero, size: size)
                gpuViewController.view.drawHierarchy(in: rec, afterScreenUpdates: true)
            }
        } else {
            // Standard cores
            let size = gpuViewController.view.frame.size
            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
            let rec = CGRect(origin: .zero, size: size)
            gpuViewController.view.drawHierarchy(in: rec, afterScreenUpdates: true)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
#if os(iOS)
    @objc func takeScreenshot() {
        if let screenshot = captureScreenshot() {
            Task.detached {
                UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
            }
            
            if let pngData = screenshot.pngData() {
                let dateString = PVEmulatorConfiguration.string(fromDate: Date())
                
                let fileName = self.game.title + " - " + dateString + ".png"
                let imageURL = PVEmulatorConfiguration.screenshotsPath(forGame: self.game).appendingPathComponent(fileName, isDirectory: false)
                do {
                    try pngData.write(to: imageURL)
                    RomDatabase.sharedInstance.asyncWriteTransaction {
                        self.game.realm?.refresh()
                        let newFile = PVImageFile(withURL: imageURL, relativeRoot: .iCloud)
                        self.game.screenShots.append(newFile)
                    }
                } catch {
                    ELOG("Unable to write image to disk, error: \(error.localizedDescription)")
                }
            }
        }
        core.setPauseEmulation(false)
        isShowingMenu = false
    }
    
#endif
    
}

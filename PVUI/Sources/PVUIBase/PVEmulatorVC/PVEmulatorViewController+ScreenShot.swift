//
//  PVEmulatoreViewController+ScreenShot.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//


// MARK: Screenshot

extension PVEmulatorViewController {
    
    public func captureScreenshot() -> UIImage? {
        fpsLabel.alpha = 0.0
        if (core.skipLayout && core.touchViewController != nil) {
            let width: CGFloat = UIScreen.main.bounds.size.width ?? 0.0
            let height: CGFloat = UIScreen.main.bounds.size.height ?? 0.0
            /// square size becuase we don't really know the size often
            /// TODO: Find a better way to do this
            let squareSize = min(width, height)
            let size = CGSize(width: squareSize, height: squareSize)
            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
            let rec = CGRect(x: 0, y: 0, width: squareSize, height: squareSize)
            core.touchViewController?.view.drawHierarchy(in: rec, afterScreenUpdates: true)
        } else {
            let width: CGFloat? = gpuViewController.view.frame.size.width > 0 ? gpuViewController.view.frame.size.width : UIScreen.main.bounds.width
            let height: CGFloat? = gpuViewController.view.frame.size.height > 0 ? gpuViewController.view.frame.size.height : UIScreen.main.bounds.height
            let size = CGSize(width: width ?? 0.0, height: height ?? 0.0)
            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
            let rec = CGRect(x: 0, y: 0, width: width ?? 0.0, height: height ?? 0.0)
            gpuViewController.view.drawHierarchy(in: rec, afterScreenUpdates: true)
        }
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        fpsLabel.alpha = 1.0
        return image
    }
    
}

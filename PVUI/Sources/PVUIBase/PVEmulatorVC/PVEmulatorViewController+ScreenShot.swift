//
//  PVEmulatoreViewController+ScreenShot.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//


// MARK: Screenshot

extension PVEmulatorViewController {

    @MainActor
    public func captureScreenshot() -> UIImage? {
        /// Safety check: ensure view controller is in a valid state
        guard isViewLoaded,
              view.window != nil,
              parent != nil || presentingViewController != nil else {
            return nil
        }

        let fpsLabelWasHidden = fpsLabel.isHidden
        let fpsHUDViewWasHidden = fpsHUDView.isHidden
        fpsLabel.isHidden = true
        fpsHUDView.isHidden = true
        defer {
            fpsLabel.isHidden = fpsLabelWasHidden
            fpsHUDView.isHidden = fpsHUDViewWasHidden
        }

        guard let targetView = screenshotTargetView() else { return nil }

        /// Safety check: ensure target view is in a valid state
        guard targetView.window != nil else { return nil }

        targetView.layoutIfNeeded()
        view.layoutIfNeeded()

        /// Ensure view hierarchy updates are committed before capture
        CATransaction.flush()

        let captureRect = resolvedScreenshotRect(for: targetView)
        guard captureRect.width > 1, captureRect.height > 1 else { return nil }

        let scale = targetView.window?.screen.scale ?? UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(captureRect.size, false, scale)

        let drawRect = CGRect(
            origin: CGPoint(x: -captureRect.origin.x, y: -captureRect.origin.y),
            size: targetView.bounds.size
        )

        targetView.drawHierarchy(in: drawRect, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    private func screenshotTargetView() -> UIView? {
        /// Safety check: ensure gpuViewController is in a valid parent-child relationship
        guard gpuViewController.parent === self else {
            return view
        }

        if let metalVC = gpuViewController as? PVMetalViewController,
           let renderView = metalVC.mtlView,
           renderView.window != nil {
            return renderView
        }

        if let gpuView = gpuViewController.view, gpuView.window != nil {
            return gpuView
        }

        return view
    }

    private func resolvedScreenshotRect(for targetView: UIView) -> CGRect {
        guard let viewportFrame = currentTargetFrame,
              targetView.isDescendant(of: view) else {
            return targetView.bounds.standardized
        }

        var converted = view.convert(viewportFrame, to: targetView)
        converted = converted.intersection(targetView.bounds)

        if converted.isRenderable {
            return converted
        } else {
            return targetView.bounds.standardized
        }
    }
}

private extension CGRect {
    var isRenderable: Bool {
        guard !isNull,
              !isInfinite,
              width.isFinite,
              height.isFinite,
              origin.x.isFinite,
              origin.y.isFinite else {
            return false
        }
        return width > 2 && height > 2
    }

    var isInfinite: Bool {
        !origin.x.isFinite || !origin.y.isFinite || !width.isFinite || !height.isFinite
    }
}

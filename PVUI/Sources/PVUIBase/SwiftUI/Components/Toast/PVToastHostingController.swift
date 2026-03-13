//
//  PVToastHostingController.swift
//  PVUI
//
//  Created by Claude on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(UIKit)
import UIKit
import SwiftUI

// MARK: - Hosting Controller

/// A `UIViewController` that hosts the `PVToastStackView` as a transparent overlay.
/// Add it as a child view controller above any emulator renderer (UIKit, Metal, GL).
///
/// ```swift
/// // In PVEmulatorViewController:
/// let toastVC = PVToastHostingController()
/// addChild(toastVC)
/// view.addSubview(toastVC.view)
/// toastVC.view.frame = view.bounds
/// toastVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
/// toastVC.didMove(toParent: self)
/// ```
public final class PVToastHostingController: UIHostingController<PVToastStackView> {

    // MARK: Lifecycle

    public convenience init(position: PVToastPosition = .bottomCenter) {
        self.init(rootView: PVToastStackView(position: position))
    }

    public override init(rootView: PVToastStackView) {
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.rootView = PVToastStackView(position: .bottomCenter)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure the hosting view passes touches through transparent areas
        view.backgroundColor = .clear
        view.isOpaque = false
        // Forward touches to underlying views when not hitting a toast
        view.isUserInteractionEnabled = true
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.frame = parent?.view.bounds ?? view.frame
    }
}

// MARK: - UIView Convenience

public extension PVToastHostingController {
    /// Installs the toast overlay as a child of `parentViewController`,
    /// pinning it to the parent's bounds and bringing it to the front.
    static func install(
        in parentViewController: UIViewController,
        position: PVToastPosition = .bottomCenter
    ) -> PVToastHostingController {
        let toastVC = PVToastHostingController(position: position)
        parentViewController.addChild(toastVC)
        parentViewController.view.addSubview(toastVC.view)
        toastVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toastVC.view.leadingAnchor.constraint(equalTo: parentViewController.view.leadingAnchor),
            toastVC.view.trailingAnchor.constraint(equalTo: parentViewController.view.trailingAnchor),
            toastVC.view.topAnchor.constraint(equalTo: parentViewController.view.topAnchor),
            toastVC.view.bottomAnchor.constraint(equalTo: parentViewController.view.bottomAnchor),
        ])
        toastVC.didMove(toParent: parentViewController)
        parentViewController.view.bringSubviewToFront(toastVC.view)
        return toastVC
    }
}
#endif

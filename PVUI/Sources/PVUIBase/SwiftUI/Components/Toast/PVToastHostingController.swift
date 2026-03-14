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
        // Ensure the hosting view is visually transparent
        view.backgroundColor = .clear
        view.isOpaque = false
        // Keep user interaction enabled so toast content remains tappable
        view.isUserInteractionEnabled = true
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if view.translatesAutoresizingMaskIntoConstraints {
            view.frame = parent?.view.bounds ?? view.frame
        }
    }
}

// MARK: - Passthrough Container

/// A container view that allows taps on its subviews (the toast stack),
/// but passes through taps that only hit the container's own background.
private final class PVToastPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        // If the hit is the container itself (background), let touches fall through
        if hitView === self {
            return nil
        }

        return hitView
    }
}

// MARK: - UIView Convenience

public extension PVToastHostingController {
    /// Installs the toast overlay as a child of `parentViewController`,
    /// pinning it to the parent's bounds and bringing it to the front.
    ///
    /// The overlay is wrapped in a passthrough container so that taps on
    /// empty/background areas fall through to the underlying views, while
    /// taps on the toast content remain interactive.
    static func install(
        in parentViewController: UIViewController,
        position: PVToastPosition = .bottomCenter
    ) -> PVToastHostingController {
        let toastVC = PVToastHostingController(position: position)

        // Container that handles hit-testing passthrough for background taps.
        let containerView = PVToastPassthroughView(frame: .zero)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        containerView.isOpaque = false

        parentViewController.view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: parentViewController.view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: parentViewController.view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: parentViewController.view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: parentViewController.view.bottomAnchor),
        ])

        parentViewController.addChild(toastVC)
        containerView.addSubview(toastVC.view)
        toastVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toastVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toastVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toastVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            toastVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        toastVC.didMove(toParent: parentViewController)
        parentViewController.view.bringSubviewToFront(containerView)

        return toastVC
    }
}
#endif

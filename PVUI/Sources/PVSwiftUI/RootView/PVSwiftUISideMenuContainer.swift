//
//  PVSwiftUISideMenuContainer.swift
//  PVUI
//
//  Created by Claude on 2026-03-29.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Replaces the UIKit `SideNavigationController` with a UIViewController
//  whose side-menu overlay is implemented as a pure-SwiftUI animated panel.
//  Phase 1 of the SideNavigationController → SwiftUI migration.
//

#if canImport(UIKit)
import UIKit
import SwiftUI
import Combine

// MARK: - PVSwiftUISideMenuContainer

/// Replaces `SideNavigationController` as the top-level container view controller.
/// Embeds the main content as a full-screen child and overlays the side menu using
/// a SwiftUI animated panel driven by `PVRootViewModel.isMenuVisible`.
public final class PVSwiftUISideMenuContainer: UIViewController {

    // MARK: - Properties

    private let viewModel: PVRootViewModel
    /// The primary content (e.g. `PVRootViewNavigationController`).
    private let mainViewController: UIViewController
    /// The side menu (e.g. a `UINavigationController` hosting `SideMenuView`).
    private let sideMenuViewController: UIViewController
    private var overlayHostingController: UIHostingController<SideMenuOverlayView>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(
        mainViewController: UIViewController,
        sideMenuViewController: UIViewController,
        viewModel: PVRootViewModel
    ) {
        self.mainViewController = mainViewController
        self.sideMenuViewController = sideMenuViewController
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Embed main content as full-screen child.
        embedFullScreen(mainViewController)

        // 2. Build the SwiftUI overlay that drives menu animation.
        let overlayView = SideMenuOverlayView(
            viewModel: viewModel,
            sideMenuViewController: sideMenuViewController
        )
        let hostingVC = UIHostingController(rootView: overlayView)
        hostingVC.view.backgroundColor = .clear
        // Start non-interactive so touches pass through to main content when menu is closed.
        hostingVC.view.isUserInteractionEnabled = false
        overlayHostingController = hostingVC
        embedFullScreen(hostingVC)

        // 3. Sync overlay interactivity with menu visibility.
        viewModel.$isMenuVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak hostingVC] isVisible in
                hostingVC?.view.isUserInteractionEnabled = isVisible
            }
            .store(in: &cancellables)

        // 4. iOS: left-edge pan gesture to initiate menu opening.
#if !os(tvOS)
        let edgePan = UIScreenEdgePanGestureRecognizer(
            target: self, action: #selector(handleEdgePan(_:)))
        edgePan.edges = .left
        view.addGestureRecognizer(edgePan)
#endif
    }

    // MARK: - Edge Pan (iOS only)

#if !os(tvOS)
    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard !viewModel.isMenuVisible else { return }
        if gesture.state == .began {
            viewModel.isMenuVisible = true
        }
    }
#endif

    // MARK: - Child VC Helpers

    private func embedFullScreen(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        child.didMove(toParent: self)
    }

    // MARK: - Status Bar / Focus Forwarding

#if os(iOS)
    public override var childForStatusBarStyle: UIViewController? { mainViewController }
    public override var childForStatusBarHidden: UIViewController? { mainViewController }
    public override var childForHomeIndicatorAutoHidden: UIViewController? { mainViewController }
    public override var childForScreenEdgesDeferringSystemGestures: UIViewController? { mainViewController }
#elseif os(tvOS)
    public override var childViewControllerForUserInterfaceStyle: UIViewController? { mainViewController }
    public override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if viewModel.isMenuVisible, let hostingVC = overlayHostingController {
            return hostingVC.preferredFocusEnvironments
        }
        return mainViewController.preferredFocusEnvironments
    }
    public override func setNeedsFocusUpdate() {
        super.setNeedsFocusUpdate()
        overlayHostingController?.setNeedsFocusUpdate()
    }
#endif
}

// MARK: - SideMenuOverlayView

/// Pure-SwiftUI view that slides the side-menu panel in/out with a spring animation
/// and dims the background when the menu is open.
private struct SideMenuOverlayView: View {
    @ObservedObject var viewModel: PVRootViewModel
    let sideMenuViewController: UIViewController

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Menu Width

    private func menuWidth(for totalWidth: CGFloat) -> CGFloat {
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        if isIpad { return totalWidth * 0.3 }
        // Compact = iPhone portrait, Regular = iPhone/iPad landscape
        return horizontalSizeClass == .compact
            ? totalWidth * 0.7
            : totalWidth * 0.4
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let menuW = menuWidth(for: geometry.size.width)
            let isOpen = viewModel.isMenuVisible

            ZStack(alignment: .topLeading) {
                // Dimming overlay — tap or swipe left to dismiss.
                Color.black
                    .opacity(isOpen ? 0.45 : 0)
                    .ignoresSafeArea()
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isOpen)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.isMenuVisible = false
                    }
#if !os(tvOS)
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onEnded { value in
                                if value.translation.width < -(menuW * 0.25)
                                    || value.velocity.width < -500 {
                                    viewModel.isMenuVisible = false
                                }
                            }
                    )
#endif

                // Side-menu panel: slides in from the left.
                SideMenuViewControllerBridge(viewController: sideMenuViewController)
                    .frame(width: menuW, height: geometry.size.height)
                    .offset(x: isOpen ? 0 : -menuW)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isOpen)
            }
        }
    }
}

// MARK: - SideMenuViewControllerBridge

/// Bridges an existing `UIViewController` into a SwiftUI view so it can participate
/// in SwiftUI layout and animations while retaining full UIKit functionality
/// (navigation bars, search controllers, etc.).
private struct SideMenuViewControllerBridge: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif // canImport(UIKit)

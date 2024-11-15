//
//  PVRootViewController.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import GameController

#if canImport(SwiftUI)
#if canImport(Combine)
#if canImport(UIKit)
import UIKit
#endif
import RxSwift
import PVUIBase
import SwiftUI
import RealmSwift
import Combine
import PVLibrary
import PVRealm
import PVLogging
import PVThemes

@_exported import PVUIBase

#if canImport(MBProgressHUD)
import MBProgressHUD
#endif

// PVRootViewController serves as a UIKit parent for child SwiftUI menu views.

// The goal one day may be to move entirely to a SwiftUI app life cycle, but under
// current circumstances (iOS 11 deployment target, some critical logic being coupled
// to UIViewControllers, etc.) it will be more easier to integrate by starting here
// and porting the remaining views/logic over to as conditions change moving forward.

public enum PVNavOption {
    case settings
    case home
    case console(consoleId: String, title: String)

    var title: String {
        switch self {
        case .settings: return "Settings"
        case .home: return "Home"
        case .console(_, let title):  return title
        }
    }
}

@available(iOS 14, tvOS 14, *)
public class PVRootViewController: UIViewController, GameLaunchingViewController, GameSharingViewController {

    let containerView = UIView()
    var viewModel: PVRootViewModel!

    var updatesController: PVGameLibraryUpdatesController!
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>!
    var gameImporter: GameImporter!

    var selectedTabCancellable: AnyCancellable?

    lazy var consolesWrapperViewDelegate = ConsolesWrapperViewDelegate()
    var consoleIdentifiersAndNamesMap: [String:String] = [:]

    private var gameController: GCController?
    private var controllerObserver: Any?

    public static func instantiate(updatesController: PVGameLibraryUpdatesController, gameLibrary: PVGameLibrary<RealmDatabaseDriver>, gameImporter: GameImporter, viewModel: PVRootViewModel) -> PVRootViewController {
        let controller = PVRootViewController()
        controller.updatesController = updatesController
        controller.gameLibrary = gameLibrary
        controller.gameImporter = gameImporter
        controller.viewModel = viewModel
        return controller
    }


    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(containerView)
        self.fillParentView(child: containerView, parent: self.view)

        self.determineInitialView()

        let hud = MBProgressHUD(view: view)
        hud.isUserInteractionEnabled = false
        hud.contentColor = ThemeManager.shared.currentPalette.settingsCellText
        view.addSubview(hud)

        setupHUDObserver(hud: hud)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupGameController()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(controllerObserver as Any)
        gameController = nil
    }

    private var cancellables = Set<AnyCancellable>()

    deinit {
        selectedTabCancellable?.cancel()
    }

    func showMenu() {
        self.sideNavigationController?.showLeftSide()
    }

    func closeMenu() {
        self.sideNavigationController?.closeSide()
    }

    func determineInitialView() {
        if let console = gameLibrary.activeSystems.first {
            didTapConsole(with: console.identifier)
        } else {
            didTapHome()
        }
    }

    func loadIntoContainer(_ navItem: PVNavOption, newVC: UIViewController) {
        // remove old view
        self.containerView.subviews.forEach { $0.removeFromSuperview() }
        self.children.forEach { $0.removeFromParent() }
        // set title
        self.navigationItem.title = navItem.title
        // set bar button items (if any)
        switch navItem {
        case .settings, .home, .console:
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), primaryAction: UIAction { _ in
                self.showMenu()
            })
        }
        // load new view
        self.addChildViewController(newVC, toContainerView: self.containerView)
        self.fillParentView(child: newVC.view, parent: self.containerView)
    }

    private func setupGameController() {
        // Observe for new controllers
        controllerObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.connectFirstController()
        }

        // Check for already connected controller
        connectFirstController()
    }

    private func connectFirstController() {
        guard gameController == nil else { return }

        if let controller = GCController.current ?? GCController.controllers().first {
            gameController = controller
            setupControllerInputs(controller)
        }
    }

    private func setupControllerInputs(_ controller: GCController) {
        controller.extendedGamepad?.leftShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            guard let self = self, pressed else { return }
            self.switchToPreviousConsole()
        }

        controller.extendedGamepad?.rightShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            guard let self = self, pressed else { return }
            self.switchToNextConsole()
        }

        controller.extendedGamepad?.buttonOptions?.valueChangedHandler = { [weak self] _, _, pressed in
            guard let self = self, pressed else { return }
            if self.sideNavigationController?.visibleSideViewController == self.sideNavigationController?.left?.viewController {
                self.closeMenu()
            } else {
                self.showMenu()
            }
        }
    }

    private func switchToNextConsole() {
        let systems = gameLibrary.activeSystems
        guard let currentSystem = systems.first(where: { $0.identifier == consolesWrapperViewDelegate.selectedTab }),
              let currentIndex = systems.firstIndex(of: currentSystem),
              currentIndex + 1 < systems.count else { return }

        let nextSystem = systems[currentIndex + 1]
        didTapConsole(with: nextSystem.identifier)
    }

    private func switchToPreviousConsole() {
        let systems = gameLibrary.activeSystems
        guard let currentSystem = systems.first(where: { $0.identifier == consolesWrapperViewDelegate.selectedTab }),
              let currentIndex = systems.firstIndex(of: currentSystem),
              currentIndex > 0 else { return }

        let previousSystem = systems[currentIndex - 1]
        didTapConsole(with: previousSystem.identifier)
    }
}

// MARK: - HUD State
/// HUD State for the view controller
extension PVRootViewController {
    private func setupHUDObserver(hud: MBProgressHUD) {
        Task { @MainActor in
            for try await state in await AppState.shared.hudCoordinator.$hudState.values {
                updateHUD(hud: hud, state: state)
            }
        }
    }
    private func updateHUD(hud: MBProgressHUD, state: HudState) {
        switch state {
        case .hidden:
            hud.hide(animated: true)
        case .title(let title, let subtitle):
            hud.show(animated: true)
            hud.mode = .indeterminate
            hud.label.text = title
            hud.label.numberOfLines = 2
            hud.detailsLabel.text = subtitle
        case .titleAndProgress(let title, let subtitle, let progress):
            hud.show(animated: true)
            hud.mode = .annularDeterminate
            hud.progress = progress
            hud.label.text = title
            hud.label.numberOfLines = 2
            hud.detailsLabel.text = subtitle
        }
    }
}

// MARK: - Helpers
extension UIViewController {

    func addChildViewController(_ child: UIViewController, toContainerView containerView: UIView) {
        addChild(child)
        containerView.addSubview(child.view)
        child.didMove(toParent: self)
    }

    func fillParentView(child: UIView, parent: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }

}

#if os(iOS) || targetEnvironment(macCatalyst)
// MARK: - UIDocumentPickerDelegate
extension PVGameLibraryViewController: UIDocumentPickerDelegate {
    public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        updatesController.handlePickedDocuments(urls)
    }

    public func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        ILOG("Document picker was cancelled")
    }
}
#endif // os(iOS)
#endif // canImport(Combine)
#endif // canImport(SwiftUI)

//
//  PVRootViewController.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import GameController
import PVFeatureFlags

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
    public var gameLibrary: PVGameLibrary<RealmDatabaseDriver>!
    var gameImporter: GameImporter!

    var selectedTabCancellable: AnyCancellable?

    lazy var consolesWrapperViewDelegate = ConsolesWrapperViewDelegate()
    var consoleIdentifiersAndNamesMap: [String:String] = [:]

    private var gameController: GCController?
    private var controllerObserver: Any?

    private var continuousNavigationTask: Task<Void, Never>?

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

        // Listen for bootup state changes
        setupBootupStateObserver()

        // Listen for app open actions
        setupAppOpenActionObserver()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupGameController()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(controllerObserver as Any)
        continuousNavigationTask?.cancel()
        gameController = nil
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // If bootup is already completed, handle app open events
        if AppState.shared.bootupState == .completed {
            ILOG("PVRootViewController: Bootup already completed, checking for app open events")

            // Get the current app open action
            let currentAction = AppState.shared.appOpenAction
            if case .none = currentAction {
                DLOG("PVRootViewController: No app open action to handle on view appear")
            } else {
                ILOG("PVRootViewController: Found app open action to handle on view appear")
                Task { @MainActor in
                    await handleAppOpenEvents(currentAction)
                }
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    deinit {
        selectedTabCancellable?.cancel()
    }

    public func showMenu() {
        viewModel.isMenuVisible = true
        self.sideNavigationController?.showLeftSide()
    }

    public func closeMenu() {
        viewModel.isMenuVisible = false
        self.sideNavigationController?.closeSide()
    }

    public func determineInitialView() {
        let consolesView = ConsolesWrapperView(consolesWrapperViewDelegate: consolesWrapperViewDelegate, viewModel: self.viewModel, rootDelegate: self)
        loadIntoContainer(.home, newVC: UIHostingController(rootView: consolesView))

        // Add observer for title updates
        selectedTabCancellable = consolesWrapperViewDelegate.$selectedTab
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedTab in
                guard let self = self else { return }
                if selectedTab == "home" {
                    self.navigationItem.title = "Home"
                } else if let console = self.gameLibrary.system(identifier: selectedTab) {
                    self.navigationItem.title = console.name
                }
            }

        // Set initial console and tab
//        if let console = gameLibrary.activeSystems.first {
//            consolesWrapperViewDelegate.selectedTab = console.identifier
//            viewModel.selectedConsole = console
//        } else {
//            consolesWrapperViewDelegate.selectedTab = "home"
//            viewModel.selectedConsole = nil
//        }
    }

    public func didTapHome() {
        consolesWrapperViewDelegate.selectedTab = "home"
        closeMenu()
    }

    public func didTapConsole(with identifier: String) {
        consolesWrapperViewDelegate.selectedTab = identifier
        closeMenu()
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
        closeMenu()
    }

    /// Sets up an observer for app open actions to handle them when they change
    private func setupAppOpenActionObserver() {
        Task { @MainActor in
            for await action in await AppState.shared.$appOpenAction.values {
                // Skip empty actions
                if case .none = action {
                    continue
                }

                ILOG("PVRootViewController: Detected new app open action: \(String(describing: action))")

                // Only process if bootup is completed
                if AppState.shared.bootupState == .completed {
                    ILOG("PVRootViewController: Processing app open action immediately")
                    await handleAppOpenEvents(action)
                } else {
                    ILOG("PVRootViewController: Bootup not completed, action will be handled after bootup")
                    // The action will be handled by the bootup state observer when bootup completes
                }
            }
        }
    }

    private func handleAppOpenEvents(_ state: AppState.AppOpenAction) async {
        ILOG("PVRootViewController: Handling app open action: \(String(describing: state))")

        // Store the current state to process
        let currentState = state

        // Reset the app open action to none immediately to avoid processing it multiple times
        if case .none = state {
            // Already none, no need to reset
        } else {
            AppState.shared.appOpenAction = .none
            DLOG("PVRootViewController: Reset appOpenAction to .none")
        }

        switch currentState {
        case .openFile(let url):
            ILOG("PVRootViewController: Opening file at URL: \(url.path)")
            // TODO: Find if we have the file by md5, or if the path is in our PVGame paths
            // if the path is outside the app folders, we need to import and then somehow
            // load the game. Ideally we could force import the game with a single import method
            // that's async
            break
        case .openMD5(let md5):
            ILOG("PVRootViewController: Opening game by MD5: \(md5)")
            guard let game = RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: md5) else {
                ELOG("PVRootViewController: No game found with md5: \(md5)")
                return
            }
            ILOG("PVRootViewController: Found game '\(game.title)' for MD5: \(md5), loading...")
            await root_load(game, sender: self, core: nil, saveState: nil)
            break
        case .openGame(let game):
            ILOG("PVRootViewController: Opening game directly: \(game.title) (MD5: \(game.md5Hash))")
            await root_load(game, sender: self, core: nil, saveState: nil)
        case .none:
            DLOG("PVRootViewController: No app open action to handle")
            break
        }
    }

    private var gamepadCancellable: AnyCancellable?

    private func setupGameController() {
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .menuToggle(let isPressed):
                    if isPressed {
                        if self.sideNavigationController?.visibleSideViewController == self.sideNavigationController?.left?.viewController {
                            self.closeMenu()
                        } else {
                            self.showMenu()
                        }
                    }
                case .shoulderLeft(let isPressed):
                    if isPressed {
                        startContinuousNavigation(isNext: false)
                    } else {
                        continuousNavigationTask?.cancel()
                        continuousNavigationTask = nil
                    }
                case .shoulderRight(let isPressed):
                    if isPressed {
                        startContinuousNavigation(isNext: true)
                    } else {
                        continuousNavigationTask?.cancel()
                        continuousNavigationTask = nil
                    }
                default:
                    continuousNavigationTask?.cancel()
                    continuousNavigationTask = nil
                }
            }
    }

    private func startContinuousNavigation(isNext: Bool) {
        continuousNavigationTask?.cancel()

        // Perform initial navigation
        if isNext {
            navigateToNext()
        } else {
            navigateToPrevious()
        }

        // Start continuous navigation
        continuousNavigationTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .milliseconds(500)) // Initial delay
            while !Task.isCancelled {
                if isNext {
                    self.navigateToNext()
                } else {
                    self.navigateToPrevious()
                }
                try? await Task.sleep(for: .milliseconds(150)) // Repeat delay
            }
        }
    }

    private func navigateToPrevious() {
        let allConsoles = gameLibrary.activeSystems
        let currentTab = consolesWrapperViewDelegate.selectedTab

        if currentTab == "home" {
            // From home, wrap to last console
            if let lastConsole = allConsoles.last {
                consolesWrapperViewDelegate.selectedTab = lastConsole.identifier
                self.viewModel.selectedConsole = lastConsole
            }
        } else if let currentIndex = allConsoles.firstIndex(where: { $0.identifier == currentTab }) {
            if currentIndex == 0 {
                // From first console, go to home
                consolesWrapperViewDelegate.selectedTab = "home"
            } else {
                // Go to previous console
                consolesWrapperViewDelegate.selectedTab = allConsoles[currentIndex - 1].identifier
                self.viewModel.selectedConsole = allConsoles[currentIndex - 1]
            }
        }
    }

    private func navigateToNext() {
        let allConsoles = gameLibrary.activeSystems
        let currentTab = consolesWrapperViewDelegate.selectedTab

        if currentTab == "home" {
            // From home, go to first console
            if let firstConsole = allConsoles.first {
                consolesWrapperViewDelegate.selectedTab = firstConsole.identifier
                self.viewModel.selectedConsole = firstConsole
            }
        } else if let currentIndex = allConsoles.firstIndex(where: { $0.identifier == currentTab }) {
            if currentIndex == allConsoles.count - 1 {
                // From last console, wrap to home
                consolesWrapperViewDelegate.selectedTab = "home"
                self.viewModel.selectedConsole = nil
            } else {
                // Go to next console
                consolesWrapperViewDelegate.selectedTab = allConsoles[currentIndex + 1].identifier
                self.viewModel.selectedConsole = allConsoles[currentIndex + 1]
            }
        }
    }

    /// Sets up an observer for the bootup state to handle app open events when bootup completes
    private func setupBootupStateObserver() {
        Task { @MainActor in
            for await _ in await AppState.shared.bootupStateManager.$currentState.values {
                if AppState.shared.bootupState == .completed {
                    ILOG("PVRootViewController: Bootup state completed, waiting before handling app open events")
                    // Add a slight delay to ensure everything is fully initialized
                    try? await Task.sleep(for: .milliseconds(500))

                    // Check if the task wasn't cancelled during the delay
                    if !Task.isCancelled {
                        ILOG("PVRootViewController: Now handling app open events after bootup completion")
                        // Get the current app open action at the time bootup completes
                        let currentAction = AppState.shared.appOpenAction
                        if case .none = currentAction {
                            DLOG("PVRootViewController: No app open action to handle after bootup")
                        } else {
                            await handleAppOpenEvents(currentAction)
                        }
                    }

                    // Break the loop since we only need to handle this once
                    break
                }
            }
        }
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

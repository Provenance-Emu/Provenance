//
//  EmulatorScene.swift
//  Provenance
//
//  Created on 2025-03-25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVUIBase
import PVLibrary
import PVRealm
import PVEmulatorCore
import PVCoreBridge
import PVLogging
import PVThemes
import RealmSwift
#if canImport(PVAppIntents)
import PVAppIntents
#endif

/// A SwiftUI scene for displaying the emulator screen and controls
public struct EmulatorScene: Scene {
    @StateObject private var appState = AppState.shared
    @StateObject private var sceneCoordinator = SceneCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some Scene {
        WindowGroup(id: "emulator") {
            EmulatorContainerView()
                .environmentObject(appState)
                .environmentObject(sceneCoordinator)
                .preferredColorScheme(ThemeManager.shared.currentPalette.dark ? .dark : .light)
                .hideHomeIndicator()
#if !os(tvOS)
                .statusBar(hidden: true)
#endif
                .onAppear {
                    ILOG("EmulatorScene: Scene appeared")
                    ILOG("EmulatorScene: AppState.shared instance: \(AppState.shared)")
                    ILOG("EmulatorScene: Current EmulationUIState: \(appState.emulationUIState)")

                    if let game = appState.emulationUIState.currentGame {
                        ILOG("EmulatorScene: Current game in EmulationUIState: \(game.title) (ID: \(game.id))")
                        ILOG("EmulatorScene: Game details - System: \(game.system?.name ?? "nil"), userPreferredCoreID: \(game.userPreferredCoreID ?? "nil")")
                    } else {
                        ELOG("EmulatorScene: No game found in EmulationUIState")
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        ILOG("EmulatorScene: Scene became active")
                        // Make sure the emulation doesn't pause when scene is active
                        if let core = appState.emulationUIState.core,
                           let emulator = appState.emulationUIState.emulator,
                           !emulator.isShowingMenu {
                            core.setPauseEmulation(false)
                        }
                    } else if newPhase == .background {
                        ILOG("EmulatorScene: Scene went to background")
                        // Pause emulation when scene goes to background
                        if let core = appState.emulationUIState.core {
                            core.setPauseEmulation(true)
                        }
                    } else if newPhase == .inactive {
                        ILOG("EmulatorScene: Scene became inactive")
                    }
                }
        }
#if !os(tvOS)
        .handlesExternalEvents(matching: ["emulator"])
        .commands {
            // Add any menu commands specific to the emulator scene
            CommandGroup(replacing: .appInfo) {
                Button("About Provenance Emulator") {
                    // Show about dialog
                }
            }

            CommandMenu("Emulation") {
                Button("Pause/Resume") {
                    if let core = appState.emulationUIState.core {
                        core.setPauseEmulation(!core.isOn)
                    }
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Take Screenshot") {
                    if let emulator = appState.emulationUIState.emulator {
                        _ = emulator.captureScreenshot()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Save State") {
                    if let emulator = appState.emulationUIState.emulator {
                        Task {
                            try? await emulator.createNewSaveState(auto: false, screenshot: emulator.captureScreenshot())
                        }
                    }
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Load State") {
                    // Show load state UI
                }
                .keyboardShortcut("l", modifiers: .command)

                Divider()

                Button("Quit Emulation") {
                    if let emulator = appState.emulationUIState.emulator {
                        Task {
                            await emulator.quit(optionallySave: true) {
                                // After quitting, return to the main scene
                                SceneCoordinator.shared.closeEmulator()
                            }
                        }
                    } else {
                        // If there's no emulator, just close the scene
                        SceneCoordinator.shared.closeEmulator()
                    }
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
            }
        }
#endif
    }
}

/// A container view that manages the emulator view controller
struct EmulatorContainerView: UIViewControllerRepresentable {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sceneCoordinator: SceneCoordinator

    // Use a coordinator to store the reference to the container view controller
    class Coordinator {
        var containerViewController: EmulatorContainerViewController?
        var parentView: EmulatorContainerView?
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        ILOG("EmulatorContainerView: Creating container view controller")
        let containerVC = EmulatorContainerViewController()
        context.coordinator.containerViewController = containerVC
        context.coordinator.parentView = self

        // Log the state of AppState and EmulationUIState
        ILOG("EmulatorContainerView: AppState.shared instance: \(AppState.shared)")
        ILOG("EmulatorContainerView: Current EmulationUIState: \(appState.emulationUIState)")

        // Do not launch here: SwiftUI may not have attached this VC to a window yet.
        // Queue the launch on the VC and let it start in `viewDidAppear`.
        if let game = appState.emulationUIState.currentGame {
            containerVC.enqueueLaunch(game: game, saveState: appState.emulationUIState.currentSaveState, core: appState.emulationUIState.currentCore)
        }

        return containerVC
    }

    /// Handles the game launch process, including core selection if needed
    private func handleGameLaunch(game: PVGame, saveState: PVSaveState?, core: PVCore?, containerVC: EmulatorContainerViewController, coordinator: Coordinator) async {
        ILOG("EmulatorContainerView: Handling game launch for \(game.title)")

        // Check if the game has a system
        guard let system = game.system else {
            ELOG("EmulatorContainerView: Game has no system, cannot launch")
            displayAndLogError(
                withTitle: "Cannot Launch Game",
                message: "This game is not associated with a system.\n\nThis usually happens when:\n• The game file is corrupted\n• The import process was interrupted\n\nTry removing the game from your library and re-importing it.",
                customActions: nil
            )
            return
        }

        // Get available cores for the system
        let availableCores = system.cores
        ILOG("EmulatorContainerView: System \(system.name) has \(availableCores.count) available cores")

        // If a core was explicitly set (e.g., from SceneCoordinator), use it
        if let explicitCore = core {
            ILOG("EmulatorContainerView: Core explicitly set: \(explicitCore.projectName), using it")
            // Verify the core is available for this system
            if availableCores.contains(where: { $0.id == explicitCore.id }) {
                await containerVC.load(game, sender: nil, core: explicitCore, saveState: saveState)
                return
            } else {
                WLOG("EmulatorContainerView: Explicitly set core \(explicitCore.projectName) is not available for system \(system.name)")
            }
        }

        // If launching with a save state, use the save state's core (save states are core-specific)
        if let saveState = saveState, let saveStateCore = saveState.core {
            ILOG("EmulatorContainerView: Save state has associated core: \(saveStateCore.projectName), using it")
            // Verify the core is available for this system
            if availableCores.contains(where: { $0.id == saveStateCore.id }) {
                await containerVC.load(game, sender: nil, core: saveStateCore, saveState: saveState)
                return
            } else {
                WLOG("EmulatorContainerView: Save state's core \(saveStateCore.projectName) is not available for system \(system.name)")
                displayAndLogError(
                    withTitle: "Core Not Available",
                    message: "The save state was created with core '\(saveStateCore.projectName)', but this core is not available for \(system.name).\n\nPlease install the required core or use a different save state.",
                    customActions: nil
                )
                return
            }
        }

        // If there's only one core, use it
        if availableCores.count == 1, let singleCore = availableCores.first {
            ILOG("EmulatorContainerView: System has only one core (\(singleCore.projectName)), using it automatically")
            await containerVC.load(game, sender: nil, core: singleCore, saveState: saveState)
            return
        }

        // If there are multiple cores, check for user preferred core
        if availableCores.count > 1 {
            ILOG("EmulatorContainerView: System has multiple cores, checking for user preferred core")

            // Check if the game has a user preferred core ID
            if let preferredCoreID = game.userPreferredCoreID, !preferredCoreID.isEmpty {
                ILOG("EmulatorContainerView: Game has user preferred core ID: \(preferredCoreID)")

                // Find the core with the matching ID
                if let preferredCore = availableCores.first(where: { $0.id == preferredCoreID }) {
                    ILOG("EmulatorContainerView: Found preferred core: \(preferredCore.projectName), using it")
                    await containerVC.load(game, sender: nil, core: preferredCore, saveState: saveState)
                    return
                } else {
                    WLOG("EmulatorContainerView: Preferred core ID \(preferredCoreID) not found in available cores")
                }
            }

            // Check if the system has a user preferred core ID
            if let systemPreferredCoreID = system.userPreferredCoreID, !systemPreferredCoreID.isEmpty {
                ILOG("EmulatorContainerView: System has user preferred core ID: \(systemPreferredCoreID)")

                // Find the core with the matching ID
                if let preferredCore = availableCores.first(where: { $0.id == systemPreferredCoreID }) {
                    ILOG("EmulatorContainerView: Found system's preferred core: \(preferredCore.projectName), using it")
                    await containerVC.load(game, sender: nil, core: preferredCore, saveState: saveState)
                    return
                } else {
                    WLOG("EmulatorContainerView: System's preferred core ID \(systemPreferredCoreID) not found in available cores")
                }
            }

            // If we get here, we need to show the core selection UI
            ILOG("EmulatorContainerView: No preferred core found, showing core selection UI")
            await MainActor.run {
                presentCoreSelection(forGame: game, saveState: saveState, sender: containerVC, coordinator: coordinator)
            }
            return
        }

        // If we get here, there are no cores available
        ELOG("EmulatorContainerView: No cores available for system \(system.name)")
        displayAndLogError(
            withTitle: "No Core Available",
            message: "No emulator core is available for \(system.name).\n\nTo fix this:\n• Make sure the required core is installed\n• Check that cores are enabled in Settings\n• Try restarting the app\n\nIf cores are still missing, you may need to reinstall the app or update cores.",
            customActions: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the view controller if needed
        if let containerVC = uiViewController as? EmulatorContainerViewController {
            context.coordinator.containerViewController = containerVC
            if let game = appState.emulationUIState.currentGame {
                containerVC.enqueueLaunch(game: game, saveState: appState.emulationUIState.currentSaveState, core: appState.emulationUIState.currentCore)
            }
        }
    }

    // MARK: - Helper Methods

    private func presentCoreSelection(forGame game: PVGame, saveState: PVSaveState?, sender: Any?, coordinator: Coordinator) {
        ILOG("EmulatorContainerView: Presenting core selection for game: \(game.title)")

        let saveStateToUse = saveState ?? AppState.shared.emulationUIState.currentSaveState

        guard let system = game.system else {
            ELOG("EmulatorContainerView: Game has no system, cannot present core selection")
            displayAndLogError(
                withTitle: "Cannot Launch Game",
                message: "This game is not associated with a system.\n\nTry removing the game from your library and re-importing it.",
                customActions: nil
            )
            return
        }

        let availableCores = Array(system.cores)

        if availableCores.isEmpty {
            ELOG("EmulatorContainerView: No cores available for system \(system.name)")
            displayAndLogError(
                withTitle: "No Core Available",
                message: "No emulator core is available for \(system.name).\n\nMake sure the required core is installed and enabled in Settings.",
                customActions: nil
            )
            return
        }

        let items = availableCores.map { core in
            let saveCount = game.saveStates.filter("core.identifier == %@", core.identifier).count
            let subtitle = formatSaveCountSubtitle(saveCount)
            return RetroSelectionItem(id: core.identifier, title: core.projectName, subtitle: subtitle)
        }

        // Capture hostingVC in a variable so onSelect/onCancel can dismiss it
        var hostingVC: UIHostingController<CoreSelectionAlertHostingView>?

        let selectionView = CoreSelectionAlertHostingView(
            title: "Select Core",
            message: "Choose a core to run \(game.title)",
            items: items,
            cores: availableCores,
            onSelect: { selectedCore in
                // Dismiss the core selection alert FIRST, then load
                hostingVC?.dismiss(animated: true) {
                    Task {
                        if let containerVC = coordinator.containerViewController {
                            await containerVC.load(game, sender: sender, core: selectedCore, saveState: saveStateToUse)
                        }
                    }
                }
            },
            onCancel: {
                ILOG("EmulatorContainerView: Core selection cancelled")
                hostingVC?.dismiss(animated: true)
            }
        )

        hostingVC = UIHostingController(rootView: selectionView)
        hostingVC?.modalPresentationStyle = .overFullScreen
        hostingVC?.modalTransitionStyle = .crossDissolve
        hostingVC?.view.backgroundColor = .clear

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            ELOG("EmulatorContainerView: No root view controller to present core selection")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        if let vc = hostingVC {
            topVC.present(vc, animated: true)
        }
    }

    private func formatSaveCountSubtitle(_ count: Int) -> String {
        switch count {
        case 0: return "No saves"
        case 1: return "1 save"
        default: return "\(count) saves"
        }
    }

    private func displayAndLogError(withTitle title: String, message: String, customActions: [UIAlertAction]?) {
        /// Get root view controller using modern API
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            ELOG("EmulatorContainerView: Could not find root view controller to present error")
            /// Fallback: just close the emulator if we can't present the alert
            AppState.shared.emulationUIState.reset()
            SceneCoordinator.shared.closeEmulator()
            return
        }

        /// Find the topmost presented view controller
        var topController = viewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if let customActions = customActions {
            for action in customActions {
                alertController.addAction(action)
            }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                ILOG("EmulatorContainerView: User dismissed error alert, returning to main scene")
                /// Reset state and close emulator immediately
                AppState.shared.emulationUIState.reset()
                SceneCoordinator.shared.closeEmulator()
            }))
        }

        topController.present(alertController, animated: true)
    }

    func updateRecentGames(_ game: PVGame) {
        // Update recent games in app state
        if let gameLibrary = appState.gameLibrary {
            // Add game to recent games list
            AppState.shared.emulationUIState.currentGame = game
        }
    }
}

/// A view controller that hosts the emulator view controller
class EmulatorContainerViewController: UIViewController, GameLaunchingViewController {
    // Delegate for handling quit completion
    var quitCompletionHandler: (() -> Void)?
    private var emulatorViewController: PVEmulatorViewController?
    private var pendingLaunch: (game: PVGame, saveState: PVSaveState?, core: PVCore?)?
    private var lastLaunchedKey: String?
    private var hasAppeared: Bool = false
    /// We intentionally do NOT show a first-frame HUD here.
    /// It conflicts with core/save selector overlays and can appear “on top” of them.

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    deinit {
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasAppeared = true
        processPendingLaunchIfPossible()
    }

    func enqueueLaunch(game: PVGame, saveState: PVSaveState?, core: PVCore?) {
        pendingLaunch = (game: game, saveState: saveState, core: core)
        processPendingLaunchIfPossible()
    }

    private func processPendingLaunchIfPossible() {
        guard hasAppeared else { return }
        guard let pending = pendingLaunch else { return }

        let key = [
            pending.game.md5Hash,
            pending.saveState?.id ?? "no-save",
            pending.core?.identifier ?? "no-core"
        ].joined(separator: "|")

        guard lastLaunchedKey != key else { return }
        lastLaunchedKey = key

        pendingLaunch = nil
        Task { @MainActor in
            await load(pending.game, sender: nil, core: pending.core, saveState: pending.saveState)
        }
    }

    // Implementation of GameLaunchingViewController protocol
    func presentCoreSelection(forGame game: PVGame, saveState: PVSaveState? = nil, sender: Any?) {
        let saveStateToUse = saveState ?? AppState.shared.emulationUIState.currentSaveState

        guard let system = game.system else {
            ELOG("EmulatorContainerViewController: Game has no system")
            return
        }

        let cores = Array(system.cores)
        guard !cores.isEmpty else {
            ELOG("EmulatorContainerViewController: No cores available")
            return
        }

        let items = cores.map { core in
            let saveCount = game.saveStates.filter("core.identifier == %@", core.identifier).count
            let subtitle: String
            switch saveCount {
            case 0: subtitle = "No saves"
            case 1: subtitle = "1 save"
            default: subtitle = "\(saveCount) saves"
            }
            return RetroSelectionItem(id: core.identifier, title: core.projectName, subtitle: subtitle)
        }

        // Capture hostingVC so onSelect/onCancel can dismiss it
        var hostingVC: UIHostingController<CoreSelectionAlertHostingView>?

        let selectionView = CoreSelectionAlertHostingView(
            title: "Select Core",
            message: "Choose a core to run \(game.title)",
            items: items,
            cores: cores,
            onSelect: { [weak self] selectedCore in
                // Dismiss the core selection alert FIRST, then load
                hostingVC?.dismiss(animated: true) {
                    Task {
                        await self?.load(game, sender: sender, core: selectedCore, saveState: saveStateToUse)
                    }
                }
            },
            onCancel: {
                hostingVC?.dismiss(animated: true)
            }
        )

        hostingVC = UIHostingController(rootView: selectionView)
        hostingVC?.modalPresentationStyle = .overFullScreen
        hostingVC?.modalTransitionStyle = .crossDissolve
        hostingVC?.view.backgroundColor = .clear
        if let vc = hostingVC {
            present(vc, animated: true)
        }
    }

    func displayAndLogError(withTitle title: String, message: String, customActions: [UIAlertAction]?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if let customActions = customActions {
            for action in customActions {
                alertController.addAction(action)
            }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                ILOG("EmulatorContainerViewController: User dismissed error alert, returning to main scene")
                // Tear down the hosted emulator (stops core/audio/timers + detaches the
                // child VC). Error paths otherwise skip quit() and leak the core+VC+Metal view.
                self?.tearDownEmulatorAndClose(optionallySave: false)
            }))
        }

        /// Find the topmost presented view controller
        var topController: UIViewController = self
        while let presented = topController.presentedViewController {
            topController = presented
        }

        topController.present(alertController, animated: true, completion: nil)
    }

    func updateRecentGames(_ game: PVGame) {
        // Update Realm recents database (inlined from protocol default to avoid infinite recursion)
        defer {
#if canImport(PVAppIntents)
            Task { @MainActor in
                WidgetDataWriter.shared.writeFromRealm()
            }
#endif
        }
        let database = RomDatabase.sharedInstance
        RomDatabase.refresh()

        let recents: Results<PVRecentGame> = database.all(PVRecentGame.self)

        let recentsMatchingGame = database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash)
        if let recentToDelete = recentsMatchingGame.first {
            do {
                try database.delete(recentToDelete)
            } catch {
                ELOG("Failed to delete recent: \(error.localizedDescription)")
            }
        }

        if recents.count >= PVMaxRecentsCount() {
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
            let newRecent = PVRecentGame(withGame: game)
            do {
                try database.add(newRecent, update: false)
                let responder = self as? UIResponder ?? UIApplication.shared
                let activity = game.spotlightActivity
                responder.userActivity = activity
            } catch {
                ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
            }
        }

        // Update recent games in app state
        AppState.shared.emulationUIState.currentGame = game
    }

    @MainActor
    private func presentEMU(withCore core: PVCore, forGame game: PVGame, source: UIView) async {
        do {
            ILOG("EmulatorContainerViewController: Creating emulator core for game: \(game.title) with core: \(core.projectName)")
            // Create emulator core instance
            guard let coreClass = NSClassFromString(core.principleClass) as? PVEmulatorCore.Type else {
                throw GameLaunchingError.generic("Could not create core class")
            }

            let emulatorCore = coreClass.init()

            let emulatorViewController = PVEmulatorViewController(game: game, core: emulatorCore)
            self.emulatorViewController = emulatorViewController

            // Set up Delta Skin directly
            Task {
                do {
//                    try await emulatorViewController.setupDeltaSkinView()
                } catch {
                    print("Error setting up Delta Skin: \(error)")
                }
            }

            // Set up quit completion handler
            quitCompletionHandler = { [weak self] in
                ILOG("EmulatorContainerViewController: Quit completion handler called")
                // Clear emulation state
                AppState.shared.emulationUIState.reset()

                // Return to main scene using TestSceneCoordinator
                SceneCoordinator.shared.closeEmulator()
            }

            // Store in app state
            AppState.shared.emulationUIState.emulator = emulatorViewController
            AppState.shared.emulationUIState.core = emulatorCore

            // Present the emulator view controller
            addChild(emulatorViewController)
            emulatorViewController.view.frame = view.bounds
            emulatorViewController.view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
            view.addSubview(emulatorViewController.view)
            emulatorViewController.didMove(toParent: self)

            // Initialize the emulator
            ILOG("EmulatorContainerViewController: Initializing core")
            emulatorViewController.initCore()

        } catch {
            ELOG("EmulatorContainerViewController: Failed to load emulator: \(error.localizedDescription)")
            displayAndLogError(withTitle: "Error", message: "Failed to load emulator: \(error.localizedDescription)", customActions: nil)
        }
    }

    /// Properly tears down the hosted emulator on ANY close path and returns to the
    /// main scene. Error/crash paths historically called `closeEmulator()` directly,
    /// which only nulls AppState — the child `PVEmulatorViewController` (with its still
    /// running core, audio, and CADisplayLink/Timer) stayed attached and was never
    /// released, leaking a full emulator instance per core-throw. `quit()` stops the
    /// core/audio/timers/observers (breaking the timer→self retain cycle); we then
    /// detach the child VC and close. Idempotent (drops the strong ref up front).
    @MainActor
    private func tearDownEmulatorAndClose(optionallySave: Bool) {
        guard let evc = emulatorViewController else {
            AppState.shared.emulationUIState.reset()
            SceneCoordinator.shared.closeEmulator()
            return
        }
        emulatorViewController = nil
        Task { @MainActor in
            await evc.quit(optionallySave: optionallySave)
            evc.willMove(toParent: nil)
            evc.view.removeFromSuperview()
            evc.removeFromParent()
            AppState.shared.emulationUIState.reset()
            SceneCoordinator.shared.closeEmulator()
        }
    }

    private func handleGameLaunchingError(_ error: GameLaunchingError, forGame game: PVGame) {
        switch error {
        case .missingBIOSes(let missingBIOSes):
            let biosList = missingBIOSes.joined(separator: ", ")
            let message = """
            This game requires BIOS files that are not currently installed:

            \(biosList)

            To fix this:
            1. Obtain the required BIOS files (you must own the original hardware)
            2. Open Files app and navigate to Provenance
            3. Place BIOS files in the BIOS folder
            4. Restart Provenance to detect the new BIOS files

            Note: BIOS files are copyrighted firmware. You must legally obtain them from hardware you own. Check the Provenance wiki for more information.
            """
            displayAndLogError(withTitle: "Missing BIOS Files", message: message, customActions: nil)
        case .systemNotFound:
            displayAndLogError(
                withTitle: "System Not Found",
                message: "The system for \(game.title) could not be found.\n\nThis usually happens when:\n• The game file is corrupted\n• The system was removed\n\nTry removing and re-importing the game.",
                customActions: nil
            )
        case .generic(let message):
            displayAndLogError(withTitle: "Error", message: message, customActions: nil)
        }
    }
}

// MARK: - Core Selection Hosting View

/// A SwiftUI view that wraps RetroSelectionAlertView for core selection
/// Note: The caller is responsible for dismissing the hosting controller
struct CoreSelectionAlertHostingView: View {
    let title: String
    let message: String
    let items: [RetroSelectionItem]
    let cores: [PVCore]
    let onSelect: (PVCore) -> Void
    let onCancel: () -> Void

    @State private var isPresented = true

    var body: some View {
        ZStack {
            if isPresented {
                RetroSelectionAlertView(
                    title: title,
                    message: message,
                    items: items,
                    isPresented: $isPresented,
                    onSelect: { selectedId in
                        if let selectedCore = cores.first(where: { $0.identifier == selectedId }) {
                            isPresented = false
                            onSelect(selectedCore)
                        }
                    },
                    onCancel: {
                        isPresented = false
                        onCancel()
                    }
                )
            }
        }
    }
}

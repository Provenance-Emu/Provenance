import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import RealmSwift
import PVLibrary
import PVUIBase
import PVRealm
import PVPrimitives
import PVSettings
import PVSystems
import PVLogging
import Defaults
#if canImport(PVAppIntents)
import PVAppIntents
#endif

/// Owns paged-library navigation and presentations without retaining view controllers.
@MainActor
final class PVLibraryNavigation: ObservableObject, PVMenuDelegate, PVRootDelegate, ImportStatusDelegate {
    enum Sheet: String, Identifiable {
        case settings, imports, freeROMs, saves, corePicker
        var id: String { rawValue }
    }

    let viewModel = PVRootViewModel()
    let tabs = ConsolesWrapperViewDelegate()
    let updatesController: PVGameLibraryUpdatesController
    let gameImporter: GameImporter
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>!
    @Published var sheet: Sheet? { didSet { updateInputOwnership() } }
    @Published var showsImportSources = false { didSet { updateInputOwnership() } }
    @Published var showsFileImporter = false { didSet { updateInputOwnership() } }
    @Published var gameForCoreSelection: PVGame?
    @Published var gameForDeletion: PVGame? { didSet { updateInputOwnership() } }
    private var deleteSaves = false
    private var importSourcesAfterDismissal = false
    private var dismissalWaiters: [CheckedContinuation<Void, Never>] = []
    var continuesViewModel: ContinuesMagementViewModel?

    init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>, updatesController: PVGameLibraryUpdatesController, gameImporter: GameImporter) {
        self.gameLibrary = gameLibrary
        self.updatesController = updatesController
        self.gameImporter = gameImporter
        selectTab(tabs.selectedTab)
    }

    private func updateInputOwnership() {
        viewModel.inputOwnership.hasLibraryPresentation = sheet != nil || showsImportSources || showsFileImporter || gameForDeletion != nil || !dismissalWaiters.isEmpty
    }

    func selectTab(_ identifier: String) {
        let console = gameLibrary.system(identifier: identifier)
        tabs.selectedTab = console?.identifier ?? "home"
        viewModel.selectedConsole = console?.freeze()
    }

    func navigate(isNext: Bool) {
        selectTab(LibraryTabSelection.destination(from: tabs.selectedTab, systems: gameLibrary.activeSystems.map(\.identifier), isNext: isNext))
    }

    func didTapHome() { viewModel.libraryDestination = .home; selectTab("home"); closeMenu() }
    func didTapConsole(with consoleId: String) { selectTab(consoleId); closeMenu() }
    func didTapCollection(with collection: Int) { showUnderConstructionAlert() }
    func closeMenu() { viewModel.isMenuVisible = false }
    func didTapSettings() { closeMenu(); sheet = .settings }
    func didTapImports() { closeMenu(); sheet = .imports }
    func didTapFreeROMs() { closeMenu(); sheet = .freeROMs }
    func didTapAddGames() { closeMenu(); showsImportSources = true }

    func handle(_ destination: ScreenDestination) {
        switch destination {
        case .library:
            sheet = nil
            didTapHome()
        case .systemBrowser(let identifier):
            sheet = nil
            didTapConsole(with: identifier)
        case .settingsRoot:
            didTapSettings()
        case .settingsVideo, .settingsAudio:
            SettingsNavigator.shared.navigate(to: .tab(.emulation))
            didTapSettings()
        case .settingsController:
            SettingsNavigator.shared.navigate(to: .tab(.controller))
            didTapSettings()
        case .settingsAdvanced:
            SettingsNavigator.shared.navigate(to: .tab(.advanced))
            didTapSettings()
        case .gameDetail(let md5):
            LibraryNavigator.shared.navigate(toGame: md5)
        case .snapshot:
            break
        }
    }

    func dismissAction() {
        sheet = nil
        Task { await gameImporter.clearCompleted() }
    }

    func addImportsAction() {
        importSourcesAfterDismissal = true
        sheet = nil
    }

    func didDismissSheet() {
        let waiters = dismissalWaiters
        dismissalWaiters.removeAll()
        waiters.forEach { $0.resume() }
        updateInputOwnership()
        if importSourcesAfterDismissal {
            importSourcesAfterDismissal = false
            showsImportSources = true
        }
    }

    func forceImportsAction() {
        Task {
            let queue = await gameImporter.importQueue
            queue.filter { $0.status.canBeRequeued }.forEach { $0.requeue() }
            gameImporter.startProcessing()
        }
    }

    func didSelectSystem(_ system: SystemIdentifier, for item: ImportQueueItem) {
        if gameImporter.processingState == .idle {
            gameImporter.startProcessing()
        } else if gameImporter.processingState == .paused {
            Task { await gameImporter.processItem(item) }
        }
    }

    func dismissPresentedViews() async {
        closeMenu()
        guard sheet != nil || !dismissalWaiters.isEmpty else { return }
        await withCheckedContinuation { continuation in
            dismissalWaiters.append(continuation)
            sheet = nil
        }
    }

    func root_canLoad(_ game: PVGame) async throws {
        guard game.system != nil else { throw GameLaunchingError.systemNotFound }
        // SceneCoordinator performs the full ROM, BIOS and save validation on every launch.
        let missing = PerGameBIOS.missingRequirements(forGame: game).filter { !$0.optional }
        if !missing.isEmpty {
            throw GameLaunchingError.missingBIOSes(PerGameBIOS.describe(missing))
        }
    }

    func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        await dismissPresentedViews()
        if let saveState {
            SceneCoordinator.shared.launchSaveState(saveState.freeze(), core: core?.freeze())
        } else {
            SceneCoordinator.shared.launchGame(game.freeze(), core: core?.freeze())
        }
    }

    func root_loadPath(_ path: String, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        await dismissPresentedViews()
        SceneCoordinator.shared.launchGame(game.freeze(), discPath: path, core: core?.freeze(), saveState: saveState?.freeze())
    }

    func root_openSaveState(_ saveState: PVSaveState) async {
        await dismissPresentedViews()
        SceneCoordinator.shared.launchSaveState(saveState.freeze())
    }

    func root_updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.sharedInstance
        guard let liveGame = game.isFrozen ? game.thaw() : game else { return }
        do {
            try database.writeTransaction {
                let recent = liveGame.recentPlays.first ?? PVRecentGame(withGame: liveGame)
                recent.lastPlayedDate = Date()
                if recent.realm == nil {
                    database.realm.add(recent)
                }
                let recents = database.realm.objects(PVRecentGame.self).sorted(byKeyPath: "lastPlayedDate", ascending: false)
                database.realm.delete(Array(recents.dropFirst(Int(PVMaxRecentsCount()))))
            }
            #if canImport(PVAppIntents)
            WidgetDataWriter.shared.writeFromRealm()
            #endif
        } catch {
            showMessage(error.localizedDescription, title: "Unable to Update Recent Games")
        }
    }

    func root_presentCoreSelection(forGame game: PVGame, sender: Any?) {
        closeMenu()
        gameForCoreSelection = game.freeze()
        sheet = .corePicker
    }

    enum CorePreference {
        case once, game, system
    }

    func chooseCore(_ core: PVCore, preference: CorePreference) {
        guard let frozenGame = gameForCoreSelection, let game = frozenGame.thaw() else { return }
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                switch preference {
                case .once: break
                case .game: game.userPreferredCoreID = core.identifier
                case .system: game.system?.userPreferredCoreID = core.identifier
                }
            }
            Task { await root_load(game.freeze(), sender: nil, core: core, saveState: nil) }
        } catch {
            showMessage(error.localizedDescription, title: "Unable to Set Preferred Core")
        }
    }

    var availableCores: [PVCore] {
        guard let game = gameForCoreSelection else { return [] }
        return game.system?.cores.filter {
            (!$0.disabled || Defaults[.unsupportedCores]) && $0.hasCoreClass && !(AppState.shared.isAppStore && $0.appStoreDisabled)
        }.sorted { $0.projectName.localizedStandardCompare($1.projectName) == .orderedAscending } ?? []
    }

    func attemptToDelete(game: PVGame, deleteSaves: Bool) {
        self.deleteSaves = deleteSaves
        gameForDeletion = game.freeze()
    }

    func confirmDeletion(_ selectedGame: PVGame) {
        guard let game = selectedGame.thaw() else { return }
        do {
            try RomDatabase.sharedInstance.delete(game: game, deleteSaves: deleteSaves)
        } catch {
            showMessage(error.localizedDescription, title: "Unable to Delete Game")
        }
        gameForDeletion = nil
    }

    func showMessage(_ message: String, title: String) {
        SceneCoordinator.shared.alertState.show(title: title, message: message, type: .standard)
    }

    func showUnderConstructionAlert() {
        showMessage("Please try again in a future update.", title: "Under Construction")
    }

    func root_showContinuesManagement(_ game: PVGame? = nil) {
        showContinues(game: game, systemID: nil)
    }

    func root_showContinuesManagement(forSystemID systemID: String) {
        showContinues(game: nil, systemID: systemID)
    }

    private func showContinues(game: PVGame?, systemID: String?) {
        let realm = RomDatabase.sharedInstance.realm
        let driver = RealmSaveStateDriver(realm: realm)
        if let game {
            driver.loadSaveStates(forGameId: game.id)
        } else {
            driver.loadAllSaveStates(forSystemID: systemID ?? "")
        }
        let numberOfSaves: Int
        if let game {
            numberOfSaves = game.saveStates.count
        } else if let systemID {
            numberOfSaves = realm.objects(PVSaveState.self).filter("game.systemIdentifier == %@", systemID).count
        } else {
            numberOfSaves = realm.objects(PVSaveState.self).count
        }
        let viewModel = ContinuesMagementViewModel(
            driver: driver,
            gameTitle: game?.title ?? "All Games",
            systemTitle: game?.system?.name ?? systemID.flatMap { gameLibrary.system(identifier: $0)?.name } ?? "All Systems",
            numberOfSaves: numberOfSaves,
            onLoadSave: { [weak self] identifier in
                Task { @MainActor in await self?.root_openSaveState(identifier) }
            }
        )
        continuesViewModel = viewModel
        #if canImport(UIKit)
        if let game {
            let frozenGame = game.freeze()
            Task { viewModel.gameUIImage = await frozenGame.fetchArtworkFromCache() }
        } else if let systemID, let system = gameLibrary.system(identifier: systemID) {
            viewModel.gameUIImage = UIImage(named: system.iconName, in: PVUIBase.BundleLoader.myBundle, compatibleWith: nil)
        }
        #endif
        closeMenu()
        sheet = .saves
    }
}

/// Shared wraparound behavior for controller shoulder navigation, including an empty library.
enum LibraryTabSelection {
    static func destination(from current: String, systems: [String], isNext: Bool) -> String {
        let identifiers = ["home"] + systems
        guard let index = identifiers.firstIndex(of: current) else { return "home" }
        let next = (index + (isNext ? 1 : identifiers.count - 1)) % identifiers.count
        return identifiers[next]
    }
}

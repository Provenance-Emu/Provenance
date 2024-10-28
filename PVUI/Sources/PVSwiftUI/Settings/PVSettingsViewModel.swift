//
//  PVSettingsViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import PVThemes
import SwiftUI
import PVLibrary
import RxSwift
import RealmSwift
import Combine
import Reachability
#if canImport(SafariServices)
import SafariServices
#endif
#if canImport(PVWebServer)
import PVWebServer
#endif

/// View Model for Settings
class PVSettingsViewModel: ObservableObject {
    @Published var currentTheme: ThemeOption = Defaults[.theme]
    @Published var numberOfConflicts: Int = 0

    #if os(tvOS) || targetEnvironment(macCatalyst)
        @Default(.largeGameArt) var largeGameArt
    #endif
    @Default(.allRightShoulders) var allRightShoulders
    @Default(.askToAutoLoad) var askToAutoLoad
    @Default(.autoJIT) var autoJIT
    @Default(.autoLoadSaves) var autoLoadSaves
    @Default(.autoSave) var autoSave
    @Default(.buttonTints) var buttonTints
    @Default(.buttonVibration) var buttonVibration
    @Default(.controllerOpacity) var controllerOpacity
    @Default(.crtFilterEnabled) var crtFilter
    @Default(.disableAutoLock) var disableAutoLock
    @Default(.use8BitdoM30) var use8BitdoM30
    @Default(.iCloudSync) var iCloudSync
    @Default(.imageSmoothing) var imageSmoothing
    @Default(.integerScaleEnabled) var integerScaleEnabled
    @Default(.lcdFilterEnabled) var lcdFilter
    @Default(.metalFilter) var metalFilter
    @Default(.missingButtonsAlwaysOn) var missingButtonsAlwaysOn
    @Default(.movableButtons) var movableButtons
    @Default(.multiSampling) var multiSampling
    @Default(.multiThreadedGL) var multiThreadedGL
    @Default(.nativeScaleEnabled) var nativeScaleEnabled
    @Default(.onscreenJoypad) var onscreenJoypad
    @Default(.onscreenJoypadWithKeyboard) var onscreenJoypadWithKeyboard
    @Default(.showFPSCount) var showFPSCount
    @Default(.timedAutoSaveInterval) var timedAutoSaveInterval
    @Default(.timedAutoSaves) var timedAutoSaves
    @Default(.unsupportedCores) var unsupportedCores
    @Default(.useMetal) var useMetalRenderer
    @Default(.useUIKit) var useUIKit
    @Default(.volume) var volume
    @Default(.volumeHUD) var volumeHUD
    @Default(.webDavAlwaysOn) var webDavAlwaysOn
    @Default(.showGameTitles) var showGameTitles
    @Default(.showRecentGames) var showRecentGames
    @Default(.showRecentSaveStates) var showRecentSaveStates
    @Default(.showGameBadges) var showGameBadges
    @Default(.showFavorites) var showFavorites

    var conflictsController: PVGameLibraryUpdatesController! {
        didSet {
            setupConflictsObserver()
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private let reachability: Reachability = try! Reachability()

    /// Metal filters
    var metalFilters: [String] {
        var filters: [String] = ["Off"]
        filters.append(contentsOf: MetalShaderManager.shared.filterShaders.map { $0.name })
        return filters
    }

    /// Check if the app is from the App Store
    var isAppStore: Bool {
        Bundle.main.infoDictionary?["ALTDeviceID"] != nil
    }

    /// Computed property to get app version
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// Computed property to get build version
    var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Git Revision (branch/hash)
    var gitRevision: String {
        let branchName = PackageBuild.info.branch?.lowercased() ?? "Unknown"

        // Note: If you get an error here, run the build again.
        // Blame Swift PM / XCode @JoeMatt
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        var revisionString = NSLocalizedString("Unknown", comment: "")
        if var bundleRevision = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
            if !isMasterBranch {
                bundleRevision = "\(branchName)/\(bundleRevision)"
            }
            revisionString = bundleRevision
        }
        return revisionString
    }

    var gitBranch: String {
        PackageBuild.info.branch?.lowercased() ?? "Unknown"
    }

    var isMasterBranch: Bool {
        gitBranch == "master" || gitBranch.starts(with: "release")
    }

    /// Computed property for build by user
    var buildUser: String {
        BuildEnvironment.userName
    }

    var incomingDateFormatter: DateFormatter = {
        // Build date string
        let incomingDateFormatter = DateFormatter()
        incomingDateFormatter.dateFormat = "E MMM d HH:mm:ss yyyy"
        return incomingDateFormatter
    }()

    var outputDateFormatter: DateFormatter = {
        let outputDateFormatter = DateFormatter()
        outputDateFormatter.dateFormat = "MM/dd/yyyy hh:mm a"
        return outputDateFormatter
    }()

    var buildDate: String {
        let gitInfo: PackageBuild = PackageBuild.info
        let buildDate = gitInfo.timeStamp
        let buildDateString: String = outputDateFormatter.string(from: buildDate)
        return buildDateString
    }

    var versionText: String {
        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !isMasterBranch {
            if isAppStore {
                versionText = "\(versionText ?? "") TestFlight"
            } else {
                versionText = "\(versionText ?? "") Beta"
            }
        }
        return versionText ?? "Unknown"
    }

    /// Function to setup conflicts observer
    public func setupConflictsObserver() {
        conflictsController?.$conflicts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conflicts in
                self?.numberOfConflicts = conflicts.count
            }
            .store(in: &cancellables)
    }

    // Function to show theme options
    func showThemeOptions() {
        let alert = UIAlertController(title: "Theme", message: "", preferredStyle: .actionSheet)

        let systemMode = UITraitCollection.current.userInterfaceStyle == .dark ? "Dark" : "Light"

        // Standard themes
        ThemeOptionsStandard.allCases.forEach { mode in
            let modeLabel = mode == .auto ? mode.description + " (\(systemMode))" : mode.description
            let action = UIAlertAction(title: modeLabel, style: .default) { [weak self] _ in
                self?.applyTheme(.standard(mode))
            }
            alert.addAction(action)
        }

        // CGA themes
        CGAThemes.allCases.forEach { cgaTheme in
            let action = UIAlertAction(title: cgaTheme.palette.name, style: .default) { [weak self] _ in
                let themeOptionCGA = ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue
                self?.applyTheme(.cga(themeOptionCGA))
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }

    private func applyTheme(_ theme: ThemeOption) {
        Task { @MainActor in
            let darkTheme: Bool
            let newTheme: any UXThemePalette

            switch theme {
            case .standard(let mode):
                darkTheme = (mode == .auto && UITraitCollection.current.userInterfaceStyle == .dark) || mode == .dark
                newTheme = darkTheme ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette
            case .cga(let cgaTheme):
                let palette = CGAThemes(rawValue: cgaTheme.rawValue)?.palette ?? ProvenanceThemes.dark.palette
                darkTheme = palette.dark
                newTheme = palette
            }

            ThemeManager.shared.setCurrentPalette(newTheme)
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = darkTheme ? .dark : .light

            Defaults[.theme] = theme
            DLOG("Saving theme to Defaults: \(theme)")

            // Apply the theme again
            ThemeManager.applySavedTheme()

            self.currentTheme = theme
        }
    }

    // Function to show help
    func showHelp() {
        #if canImport(SafariServices)
        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
            let webVC = SFSafariViewController(url: URL(string: "https://wiki.provenance-emu.com/")!)
            rootViewController.present(webVC, animated: true)
        }
        #endif
    }

    // Function to reimport ROMs
    func reimportROMs() {
        let alert = UIAlertController(
            title: "Re-Scan all ROM Directories?",
            message: """
                Attempt scan all ROM Directories,
                import all new ROMs found, and update existing ROMs
                """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            NotificationCenter.default.post(name: NSNotification.Name.PVReimportLibrary, object: nil)
        })

        alert.addAction(UIAlertAction(title: "No", style: .cancel))

        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    // Function to reset data
    func resetData() {
        let alert = UIAlertController(
            title: "Reset Everything?",
            message: """
                Attempt to delete all settings / configurations, then
                reimport everything.
                """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            NotificationCenter.default.post(name: NSNotification.Name.PVResetLibrary, object: nil)
        })

        alert.addAction(UIAlertAction(title: "No", style: .cancel))

        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    // Function to refresh game library
    func refreshGameLibrary() {
        let alert = UIAlertController(
            title: "Refresh Game Library?",
            message: """
                Attempt to reload the artwork and title
                information for your entire library.
                This can be a slow process, especially for
                large libraries.
                Only do this if you really, really want to
                try and get more artwork or update the information.
                """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
        })

        alert.addAction(UIAlertAction(title: "No", style: .cancel))

        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    // Function to empty image cache
    func emptyImageCache() {
        let alert = UIAlertController(
            title: "Empty Image Cache?",
            message: "Empty artwork cache to free up space. Images will be re-downloaded when needed.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { _ in
            do {
                try PVMediaCache.empty()
            } catch {
                // TODO: Present error
            }
        })

        alert.addAction(UIAlertAction(title: "No", style: .cancel))

        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    func launchWebServer() {
        #if canImport(PVWebServer)
        if reachability.connection == .wifi {
            // connected via wifi, let's continue
            // start web transfer service
            if PVWebServer.shared.startServers() {
                // show alert view
                let alert = UIAlertController(
                    title: "Web Server Active",
                    message: """
                        Visit \(PVWebServer.shared.webDavURLString) in your browser

                        Web browser file management requires WebDAV support.
                        We recommend:
                        • macOS Finder
                        • Windows: WinSCP
                        • iOS: Documents by Readdle
                        """,
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: "OK", style: .default))

                if let window = UIApplication.shared.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.present(alert, animated: true)
                }
            } else {
                // Display error
                let alert = UIAlertController(
                    title: "Unable to start web server!",
                    message: "Check your network connection or settings and free up ports: 80, 81.",
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: "OK", style: .default))

                if let window = UIApplication.shared.windows.first,
                   let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
                    rootViewController.present(alert, animated: true)
                }
            }
        } else {
            let alert = UIAlertController(
                title: "Unable to start web server!",
                message: "Your device needs to be connected to a WiFi network to continue!",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))

            if let window = UIApplication.shared.windows.first,
               let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
#endif
    }

    // Add these computed properties
    var crtFilterEnabled: Bool {
        get { Defaults[.crtFilterEnabled] }
        set {
            Defaults[.crtFilterEnabled] = newValue
            if newValue {
                // Turn off LCD filter if CRT is enabled
                Defaults[.lcdFilterEnabled] = false
            }
        }
    }

    var lcdFilterEnabled: Bool {
        get { Defaults[.lcdFilterEnabled] }
        set {
            Defaults[.lcdFilterEnabled] = newValue
            if newValue {
                // Turn off CRT filter if LCD is enabled
                Defaults[.crtFilterEnabled] = false
            }
        }
    }
}

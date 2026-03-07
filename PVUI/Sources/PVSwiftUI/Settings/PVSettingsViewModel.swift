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
import PVShaders
#if canImport(SafariServices)
import SafariServices
#endif
#if canImport(PVWebServer)
import PVWebServer
#endif

/// View Model for Settings
class PVSettingsViewModel: ObservableObject {

    weak var menuDelegate: PVMenuDelegate!

    init(menuDelegate: PVMenuDelegate!, conflictsController: PVGameLibraryUpdatesController) {
        self.menuDelegate = menuDelegate
        self.conflictsController = conflictsController
    }

    @ObservedObject var conflictsController: PVGameLibraryUpdatesController {
        didSet {
            setupConflictsObserver()
        }
    }

    @Published var numberOfConflicts: Int = 0
    @AppStorage("showFeatureFlagsDebug") internal var showFeatureFlagsDebug = false

    private var cancellables = Set<AnyCancellable>()
    private let reachability = try? Reachability()

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
                versionText = "\(versionText ?? "") AppStore"
            } else {
                versionText = "\(versionText ?? "") Beta"
            }
        }
        return versionText ?? "Unknown"
    }

    /// Function to setup conflicts observer
    public func setupConflictsObserver() {
        conflictsController.$conflicts
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

    // MARK: - Library Management Actions

    /// Scan ROM directories for new or updated files.
    func reimportROMs() {
        let alert = UIAlertController(
            title: "Scan ROM Directories?",
            message: "Scan all ROM directories for new or updated files. Existing custom artwork and names are not changed.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Scan", style: .default) { [weak self] _ in
            self?.menuDelegate?.didTapScanROMs()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        presentAlert(alert)
    }

    /// Delete all game data and settings, then re-import everything.
    func resetData() {
        let alert = UIAlertController(
            title: "Reset Library?",
            message: "This will delete all game data, settings, and custom artwork, then re-import everything from scratch. This cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.menuDelegate?.didTapResetLibrary()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        presentAlert(alert)
    }

    /// Re-fetch metadata and artwork from the database.
    func refreshGameLibrary() {
        let alert = UIAlertController(
            title: "Update Game Metadata?",
            message: "Re-fetch artwork and title information from the database for your entire library. Your custom artwork and names will not be changed. This can be slow for large libraries.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            self?.menuDelegate?.didTapUpdateMetadata()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        presentAlert(alert)
    }

    /// Clear the artwork cache to free up disk space.
    func emptyImageCache() {
        let alert = UIAlertController(
            title: "Clear Artwork Cache?",
            message: "Delete all cached artwork to free up disk space. Images will be re-downloaded automatically when needed.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Clear Cache", style: .destructive) { _ in
            do {
                try PVMediaCache.empty()
            } catch {
                // TODO: Present error
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        presentAlert(alert)
    }

    private func presentAlert(_ alert: UIViewController) {
        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    func launchWebServer() {
        menuDelegate?.didTapAddGames()
    }

}

extension PVSettingsViewModel {
    enum WebServerError: LocalizedError {
        case noWiFiConnection
        case serverStartFailed
        case unsupported

        var errorDescription: String? {
            switch self {
            case .noWiFiConnection:
                return "Your device needs to be connected to a Wi-Fi network to continue!"
            case .serverStartFailed:
                return "Check your network connection or settings and free up ports: 80, 81."
            case .unsupported:
                return "Unsupported platform!"
            }
        }

        var title: String {
            switch self {
            case .noWiFiConnection, .serverStartFailed:
                return "Unable to start web server!"
            case .unsupported:
                return "Unsupported platform!"
            }
        }
    }
}

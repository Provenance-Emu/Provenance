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

    /// Confirmation state published to the View layer for SwiftUI `.alert()` presentation.
    @Published var pendingLibraryAction: LibraryAction?

    /// Set pending action — the View presents a confirmation alert via `.alert()`.
    func reimportROMs() { pendingLibraryAction = .scanROMs }
    func resetData() { pendingLibraryAction = .resetLibrary }
    func refreshGameLibrary() { pendingLibraryAction = .updateMetadata }
    func emptyImageCache() { pendingLibraryAction = .clearArtworkCache }

    /// Execute the confirmed action and clear pending state.
    func confirmLibraryAction() {
        guard let action = pendingLibraryAction else { return }
        pendingLibraryAction = nil
        switch action {
        case .scanROMs:
            menuDelegate?.didTapScanROMs()
        case .updateMetadata:
            menuDelegate?.didTapUpdateMetadata()
        case .clearArtworkCache:
            // PVMediaCache.empty() is synchronous and local — no notification needed.
            do { try PVMediaCache.empty() } catch { }
        case .resetLibrary:
            menuDelegate?.didTapResetLibrary()
        }
    }

    func launchWebServer() {
        menuDelegate?.didTapAddGames()
    }

}

extension PVSettingsViewModel {
    /// Confirmable library management actions presented as SwiftUI alerts.
    enum LibraryAction: Identifiable {
        case scanROMs
        case resetLibrary
        case updateMetadata
        case clearArtworkCache

        var id: String {
            switch self {
            case .scanROMs:        return "scanROMs"
            case .resetLibrary:    return "resetLibrary"
            case .updateMetadata:  return "updateMetadata"
            case .clearArtworkCache: return "clearArtworkCache"
            }
        }

        var title: String {
            switch self {
            case .scanROMs:        return "Scan ROM Directories?"
            case .resetLibrary:    return "Reset Library?"
            case .updateMetadata:  return "Update Game Metadata?"
            case .clearArtworkCache: return "Clear Artwork Cache?"
            }
        }

        var message: String {
            switch self {
            case .scanROMs:
                return "Scan all ROM directories for new or updated files. Existing custom artwork and names are not changed."
            case .resetLibrary:
                return "This will delete all game data, settings, and custom artwork, then re-import everything from scratch. This cannot be undone."
            case .updateMetadata:
                return "Re-fetch artwork and title information from the database for your entire library. Your custom artwork and names will not be changed. This can be slow for large libraries."
            case .clearArtworkCache:
                return "Delete all cached artwork to free up disk space. Images will be re-downloaded automatically when needed."
            }
        }

        var confirmButtonTitle: String {
            switch self {
            case .scanROMs:        return "Scan"
            case .resetLibrary:    return "Reset"
            case .updateMetadata:  return "Update"
            case .clearArtworkCache: return "Clear Cache"
            }
        }

        var isDestructive: Bool {
            switch self {
            case .resetLibrary, .clearArtworkCache: return true
            case .scanROMs, .updateMetadata: return false
            }
        }
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

import SwiftUI
import PVLibrary
import PVSupport
import PVLogging
import Reachability
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import Combine
import PVUIBase
import PVUIKit
#if canImport(FreemiumKit)
import FreemiumKit
#endif
#if canImport(SafariServices)
import SafariServices
#endif
#if canImport(PVWebServer)
import PVWebServer
#endif

// MARK: - PVSettingsView
public struct PVSettingsView: View {
    /// View model for managing settings state and logic
    @StateObject private var viewModel = PVSettingsViewModel()
    /// Environment variable for dismissing the view
    @Environment(\.presentationMode) var presentationMode

    /// State manager observable conflicts controller
    let conflictsController: PVGameLibraryUpdatesController

    /// Body of the view
    public var body: some View {
        NavigationView {
            List {
                appSection
                coreOptionsSection
                savesSection
                audioSection
                videoSection
                metalSection
                controllerSection
                librarySection
                librarySection2
                advancedSection
                socialLinksSection
                documentationSection
                buildSection
                extraInfoSection
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(leading: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Help") {
                viewModel.showHelp()
            })
        }
        .onAppear {
            // Set the conflicts controller
            viewModel.conflictsController = conflictsController
        }
    }

    /// Section for app-related settings
    var appSection: some View {
        Section(header: Text("App")) {
            NavigationLink(destination: SystemSettingsView()) {
                SettingsRow(title: "Systems",
                           subtitle: "Information on cores, their bioses, links and stats.",
                           icon: .sfSymbol("square.stack.3d.down.forward"))
            }
            Button(action: viewModel.showThemeOptions) {
                SettingsRow(title: "Theme",
                           value: viewModel.currentTheme.description,
                           icon: .sfSymbol("paintpalette"))
            }
            NavigationLink(destination: AppearanceView()) {
                SettingsRow(title: "Appearance",
                           subtitle: "Visual options for Game Library",
                           icon: .sfSymbol("eye"))
            }
        }
    }

    /// Section for core options settings
    var coreOptionsSection: some View {
        Section(header: Text("Core Options")) {
            NavigationLink(destination: CoreOptionsView()) {
                SettingsRow(title: "Core Options",
                           subtitle: "Configure emulator core settings.",
                            icon: .sfSymbol("gearshape.2"))
            }
        }
    }

    /// Section for saves settings
    var savesSection: some View {
        Section(header: Text("Saves")) {
            Toggle(isOn: $viewModel.autoSave) {
                SettingsRow(title: "Auto Save", subtitle: "Auto-save game state on close. Must be playing for 30 seconds more.", icon: .sfSymbol("autostartstop"))
            }
            Toggle(isOn: $viewModel.timedAutoSaves) {
                SettingsRow(title: "Timed Auto Saves", subtitle: "Periodically create save states while you play.", icon: .sfSymbol("clock.badge"))
            }
            Toggle(isOn: $viewModel.autoLoadSaves) {
                SettingsRow(title: "Auto Load Saves", subtitle: "Automatically load the last save of a game if one exists. Disables the load prompt.", icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark"))
            }
            Toggle(isOn: $viewModel.askToAutoLoad) {
                SettingsRow(title: "Ask to Load Saves", subtitle: "Prompt to load last save if one exists. Off always boots from BIOS unless auto load saves is active.", icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark"))
            }

            HStack {
                Text("Auto-save Time")
                Slider(value: $viewModel.timedAutoSaveInterval, in: 1...30, step: 1) {
                    Text("Auto-save Time")
                } minimumValueLabel: {
                    Image(systemName: "hare")
                } maximumValueLabel: {
                    Image(systemName: "tortoise")
                }
            }
            Text("Number of minutes between timed auto saves.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Section for audio settings
    var audioSection: some View {
        Section(header: Text("Audio / Video")) {
            Toggle(isOn: $viewModel.volumeHUD) {
                SettingsRow(title: "Volume HUD",
                           subtitle: "Show volume indicator when changing volume.",
                            icon: .sfSymbol("speaker.wave.2"))
            }
            HStack {
                Text("Volume")
                Slider(value: $viewModel.volume, in: 0...1, step: 0.1) {
                    Text("Volume Level")
                } minimumValueLabel: {
                    Image(systemName: "speaker")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3")
                }
            }
            Text("System-wide volume level for games.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Section for video settings
    var videoSection: some View {
        Section(header: Text("Audio / Video")) {
            Toggle(isOn: $viewModel.multiThreadedGL) {
                SettingsRow(title: "Multi-threaded Rendering",
                           subtitle: "Improves performance but may cause graphical glitches.",
                            icon: .sfSymbol("cpu"))
            }
            Toggle(isOn: $viewModel.multiSampling) {
                SettingsRow(title: "4X Multisampling GL",
                           subtitle: "Smoother graphics at the cost of performance.",
                           icon: .sfSymbol("square.stack.3d.up"))
            }
            Toggle(isOn: $viewModel.nativeScaleEnabled) {
                SettingsRow(title: "Native Scaling",
                           subtitle: "Use the original console's resolution.",
                           icon: .sfSymbol("arrow.up.left.and.arrow.down.right"))
            }
            Toggle(isOn: $viewModel.integerScaleEnabled) {
                SettingsRow(title: "Integer Scaling",
                           subtitle: "Scale by whole numbers only for pixel-perfect display.",
                           icon: .sfSymbol("square.grid.4x3.fill"))
            }
            Toggle(isOn: $viewModel.imageSmoothing) {
                SettingsRow(title: "Image Smoothing",
                           subtitle: "Smooth scaled graphics. Off for sharp pixels.",
                           icon: .sfSymbol("paintbrush.pointed"))
            }
            Toggle(isOn: $viewModel.showFPSCount) {
                SettingsRow(title: "FPS Counter",
                           subtitle: "Show frames per second counter.",
                           icon: .sfSymbol("speedometer"))
            }
            filtersSection
        }
    }

    /// Filters sub-section
    var filtersSection: some View {
        Section(header: Text("Filters")) {
            Toggle(isOn: $viewModel.crtFilter) {
                SettingsRow(title: "CRT Filter",
                           subtitle: "Emulate a CRT TV gridding and bloom filter.",
                            icon: .sfSymbol("inset.filled.tv"))
            }
            Toggle(isOn: $viewModel.lcdFilter) {
                SettingsRow(title: "LCD Filter",
                           subtitle: "Emulate a LCD screen gridding and blur filter.",
                            icon: .sfSymbol("tv"))
            }
        }
    }

    /// Section for metal settings
    var metalSection: some View {
        Section(header: Text("Metal")) {
            Toggle(isOn: $viewModel.useMetalRenderer) {
                SettingsRow(title: "Use Metal Renderer",
                           subtitle: "Modern graphics API. Disable to use OpenGL.",
                           icon: .sfSymbol("cpu"))
            }
            Picker("Metal Filter", selection: $viewModel.metalFilter) {
                ForEach(viewModel.metalFilters, id: \.self) { filter in
                    Text(filter)
                }
            }
        }
    }

    /// Section for controller settings
    var controllerSection: some View {
        Section(header: Text("Controllers")) {
            NavigationLink(destination: ControllerSettingsView()) {
                SettingsRow(title: "Controller Settings",
                           subtitle: "Configure external controller mappings.",
                           icon: .sfSymbol("gamecontroller"))
            }
            NavigationLink(destination: ICadeControllerView()) {
                SettingsRow(title: "iCade / 8Bitdo",
                           subtitle: "Configure iCade and 8Bitdo controller settings.",
                           icon: .sfSymbol("keyboard"))
            }
        }
    }

    /// On-Screen Controller settings sub-section
    var onScreenControllerSection: some View {
        Section(header: Text("On-Screen Controller")) {
            Toggle(isOn: $viewModel.buttonTints) {
                SettingsRow(title: "Button Colors",
                           subtitle: "Show colored buttons matching original hardware.",
                           icon: .sfSymbol("paintpalette"))
            }
            Toggle(isOn: $viewModel.allRightShoulders) {
                SettingsRow(title: "All Right Shoulder Buttons",
                           subtitle: "Show all shoulder buttons on the right side.",
                           icon: .sfSymbol("l.joystick.tilt.right"))
            }
            Toggle(isOn: $viewModel.buttonVibration) {
                SettingsRow(title: "Haptic Feedback",
                           subtitle: "Vibrate when pressing on-screen buttons.",
                           icon: .sfSymbol("hand.point.up.braille"))
            }
            Toggle(isOn: $viewModel.missingButtonsAlwaysOn) {
                SettingsRow(title: "Missing Buttons Always On",
                           subtitle: "Always show buttons not present on original hardware.",
                           icon: .sfSymbol("l.rectangle.roundedbottom"))
            }
        }
    }

    // Section for library settings
    var librarySection: some View {
        Section(header: Text("Library")) {
            Button(action: viewModel.launchWebServer) {
                SettingsRow(title: "Launch Web Server",
                           subtitle: "Transfer ROMs and saves over WiFi.",
                           icon: .sfSymbol("xserve"))
            }
            NavigationLink(destination: ConflictsView().environmentObject(viewModel)) {
                SettingsRow(title: "Manage Conflicts",
                           subtitle: "Resolve conflicting save states and files.",
                           value: "\(viewModel.numberOfConflicts)",
                           icon: .sfSymbol("bandage"))
            }
        }
    }

    // Section for library settings
    var librarySection2: some View {
        Section(header: Text("Library")) {
            Button(action: viewModel.reimportROMs) {
                SettingsRow(title: "Re-import ROMs",
                           subtitle: "Scan ROM directories for new or updated files.",
                           icon: .sfSymbol("triangle.circle.fill"))
            }
            Button(action: viewModel.resetData) {
                SettingsRow(title: "Reset Data",
                           subtitle: "Delete all settings and configurations.",
                           icon: .sfSymbol("delete.forward.fill"))
            }
            Button(action: viewModel.refreshGameLibrary) {
                SettingsRow(title: "Refresh Game Library",
                           subtitle: "Update artwork and game information.",
                           icon: .sfSymbol("arrow.uturn.forward"))
            }
            Button(action: viewModel.emptyImageCache) {
                SettingsRow(title: "Empty Image Cache",
                           subtitle: "Clear cached artwork to free space.",
                           icon: .sfSymbol("trash"))
            }
        }
    }

    // Section for advanced settings
    var advancedSection: some View {
        Section(header: Text("Advanced")) {
            Toggle(isOn: $viewModel.useMetalRenderer) {
                SettingsRow(title: "Use Metal Renderer",
                           subtitle: "Modern graphics API for better performance.",
                           icon: .sfSymbol("m.square.fill"))
            }
            Toggle(isOn: $viewModel.useUIKit) {
                SettingsRow(title: "Use Legacy UIKit UI",
                           subtitle: "Switch to classic interface. Requires app restart.",
                           icon: .sfSymbol("swift"))
            }
            Toggle(isOn: $viewModel.movableButtons) {
                SettingsRow(title: "Movable Buttons",
                           subtitle: "Allow moving on-screen buttons. Triple-tap with three fingers to toggle.",
                           icon: .sfSymbol("arrow.up.and.down.and.arrow.left.and.right"))
            }
            Toggle(isOn: $viewModel.onscreenJoypad) {
                SettingsRow(title: "On-screen Joypad",
                           subtitle: "Show touch joystick on supported systems.",
                           icon: .sfSymbol("l.joystick.tilt.left.fill"))
            }
        }
    }

    // Section for social links
    var socialLinksSection: some View {
        Section(header: Text("Social")) {
            Link(destination: URL(string: "https://www.patreon.com/provenance")!) {
                SettingsRow(title: "Patreon",
                           subtitle: "Support us on Patreon.",
                           icon: .named("patreon"))
            }
            Link(destination: URL(string: "https://discord.gg/4TK7PU5")!) {
                SettingsRow(title: "Discord",
                           subtitle: "Join our Discord server for help and community chat.",
                           icon: .named("discord"))
            }
            Link(destination: URL(string: "https://twitter.com/provenanceapp")!) {
                SettingsRow(title: "X",
                           subtitle: "Follow us on X for release and other announcements.",
                           icon: .named("x"))
            }
            Link(destination: URL(string: "https://www.youtube.com/channel/UCKeN6unYKdayfgLWulXgB1w")!) {
                SettingsRow(title: "YouTube",
                           subtitle: "Help tutorial videos and new feature previews.",
                           icon: .named("youtube"))
            }
            Link(destination: URL(string: "https://github.com/Provenance-Emu/Provenance")!) {
                SettingsRow(title: "GitHub",
                           subtitle: "Check out GitHub for code, reporting bugs and contributing.",
                           icon: .named("github"))
            }
        }
    }

    // Section for documentation
    var documentationSection: some View {
        Section(header: Text("Documentation")) {
            Link(destination: URL(string: "https://provenance-emu.com/blog/")!) {
                SettingsRow(title: "Blog",
                           subtitle: "Release announcements and full changelogs and screenshots posted to our blog.",
                           icon: .sfSymbol("square.and.pencil"))
            }
            Link(destination: URL(string: "https://wiki.provenance-emu.com/faqs")!) {
                SettingsRow(title: "FAQ",
                           subtitle: "Frequently asked questions.",
                           icon: .sfSymbol("questionmark.folder.fill"))
            }
            Link(destination: URL(string: "https://wiki.provenance-emu.com/")!) {
                SettingsRow(title: "Wiki",
                           subtitle: "Full usage documentation, tips and tricks on our Wiki.",
                           icon: .sfSymbol("books.vertical.fill"))
            }
        }
    }

    /// Section for build information
    var buildSection: some View {
        Section(header: Text("Build Information")) {
            SettingsRow(title: "Version",
                       subtitle: "Current app version.",
                       value: viewModel.versionText,
                       icon: .sfSymbol("info.circle"))
            SettingsRow(title: "Build",
                       subtitle: "Internal build number.",
                       value: viewModel.buildVersion,
                       icon: .sfSymbol("hammer"))
            SettingsRow(title: "Git Revision",
                       subtitle: "Source code version.",
                       value: viewModel.gitRevision,
                       icon: .sfSymbol("chevron.left.forwardslash.chevron.right"))
            SettingsRow(title: "Built By",
                       subtitle: "Developer who built this version.",
                       value: viewModel.buildUser,
                       icon: .sfSymbol("person"))
            SettingsRow(title: "Build Date",
                       subtitle: "When this version was compiled.",
                       value: viewModel.buildDate,
                       icon: .sfSymbol("calendar"))
        }
    }

    /// Section for displaying extra information
    var extraInfoSection: some View {
        Section(header: Text("3rd Party & Legal")) {
            NavigationLink(destination: CoreProjectsView()) {
                SettingsRow(title: "Cores",
                           subtitle: "Emulator cores provided by these projects.",
                           icon: .sfSymbol("square.3.layers.3d.middle.filled"))
            }
            NavigationLink(destination: LicensesView()) {
                SettingsRow(title: "Licenses",
                           subtitle: "Open-source libraries Provenance uses and their respective licenses.",
                           icon: .sfSymbol("doc.text"))
            }
        }
    }
}

/// Row View for Settings
struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var icon: SettingsIcon? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let value = value {
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
}

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
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let webVC = SFSafariViewController(url: URL(string: "https://wiki.provenance-emu.com/")!)
            rootViewController.present(webVC, animated: true)
        }
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

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
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

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
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

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
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

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
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

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
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

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
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

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
#endif
    }
}

struct SystemSettingsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SystemsSettingsTableViewController {
        return SystemsSettingsTableViewController()
    }

    func updateUIViewController(_ uiViewController: SystemsSettingsTableViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct CoreOptionsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CoreOptionsTableViewController {
        return CoreOptionsTableViewController()
    }

    func updateUIViewController(_ uiViewController: CoreOptionsTableViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct CoreProjectsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PVCoresTableViewController {
        return PVCoresTableViewController()
    }

    func updateUIViewController(_ uiViewController: PVCoresTableViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct LicensesView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PVLicensesViewController {
        return PVLicensesViewController()
    }

    func updateUIViewController(_ uiViewController: PVLicensesViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct ICadeControllerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PViCadeControllerViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "PViCadeControllerViewController") as! PViCadeControllerViewController
    }

    func updateUIViewController(_ uiViewController: PViCadeControllerViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct ControllerSettingsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PVControllerSelectionViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "PVControllerSelectionViewController") as! PVControllerSelectionViewController
    }

    func updateUIViewController(_ uiViewController: PVControllerSelectionViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct ConflictsView: UIViewControllerRepresentable {
    @EnvironmentObject var viewModel: PVSettingsViewModel

    func makeUIViewController(context: Context) -> PVConflictViewController {
        return PVConflictViewController(conflictsController: viewModel.conflictsController)
    }

    func updateUIViewController(_ uiViewController: PVConflictViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct AppearanceView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PVAppearanceViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: PVUI_IOS.BundleLoader.bundle)
        return storyboard.instantiateViewController(withIdentifier: "PVAppearanceViewController") as! PVAppearanceViewController
    }

    func updateUIViewController(_ uiViewController: PVAppearanceViewController, context: Context) {
        // Update the view controller if needed
    }
}

public enum SettingsIcon: Equatable {
    case named(String, Bundle? = nil)
    case sfSymbol(String)

    var image: Image {
        switch self {
        case .named(let name, let bundle):
            if let bundle = bundle {
                return Image(name, bundle: bundle)
            } else {
                return Image(name)
            }
        case .sfSymbol(let name):
            return Image(systemName: name)
        }
    }

    var highlightedImage: Image? {
        switch self {
        case .named(let name, let bundle):
            let highlightedName = name + "-highlighted"
            if let bundle = bundle {
                if bundle.path(forResource: highlightedName, ofType: nil) != nil {
                    return Image(highlightedName, bundle: bundle)
                }
            } else if Bundle.main.path(forResource: highlightedName, ofType: nil) != nil {
                return Image(highlightedName)
            }
            return nil
        case .sfSymbol:
            return nil
        }
    }
}

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
import RxRealm
import RxSwift
import RealmSwift
import Perception
import PVFeatureFlags
import Defaults

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

    @StateObject private var viewModel: PVSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    var dismissAction: () -> Void
    weak var menuDelegate: PVMenuDelegate!

    @ObservedObject var conflictsController: PVGameLibraryUpdatesController

    // Update initializer to take dismissAction
    public init(conflictsController: PVGameLibraryUpdatesController, menuDelegate: PVMenuDelegate, dismissAction: @escaping () -> Void) {
        self.conflictsController = conflictsController
        self.dismissAction = dismissAction
        _viewModel = StateObject(wrappedValue: PVSettingsViewModel(menuDelegate: menuDelegate, conflictsController: conflictsController))
    }

    public var body: some View {
        NavigationView {
            List {
                CollapsibleSection(title: "App") {
                    AppSection(viewModel: viewModel)
                        .environmentObject(viewModel)
                }

                CollapsibleSection(title: "Core Options") {
                    CoreOptionsSection()
                }

                CollapsibleSection(title: "Saves") {
                    SavesSection()
                }

                CollapsibleSection(title: "Audio") {
                    AudioSection()
                }

                CollapsibleSection(title: "Video") {
                    VideoSection()
                }

                CollapsibleSection(title: "Controller") {
                    ControllerSection()
                }

                CollapsibleSection(title: "Library") {
                    LibrarySection(viewModel: viewModel)
                        .environmentObject(viewModel)
                }

                CollapsibleSection(title: "Library Management") {
                    LibrarySection2(viewModel: viewModel)
                        .environmentObject(viewModel)
                }

                CollapsibleSection(title: "Advanced") {
                    AdvancedSection()
                }

                #if !os(tvOS)
                CollapsibleSection(title: "Social Links") {
                    SocialLinksSection()
                }

                CollapsibleSection(title: "Documentation") {
                    DocumentationSection()
                }
                #endif

                CollapsibleSection(title: "Build") {
                    BuildSection(viewModel: viewModel)
                        .environmentObject(viewModel)
                }

                CollapsibleSection(title: "Extra Info") {
                    ExtraInfoSection()
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Settings")
            #if !os(tvOS)
            .navigationBarItems(
                leading: Button("Done") { dismissAction() },  // Use dismissAction here
                trailing: Button("Help") { viewModel.showHelp() }
            )
            #endif
        }
        .navigationViewStyle(StackNavigationViewStyle())
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

// MARK: - Section Views
private struct AppSection: View {
    @ObservedObject var viewModel: PVSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var iconManager = IconManager.shared

    var body: some View {
        Section(header: Text("App")) {

            /// Information about PVSystems
            NavigationLink(destination: SystemSettingsView()) {
                SettingsRow(title: "Systems",
                            subtitle: "Information on system cores, their bioses, links and stats.",
                            icon: .sfSymbol("square.stack.3d.down.forward"))
            }

            /// Links to projects
            NavigationLink(destination: CoreProjectsView()) {
                SettingsRow(title: "Cores",
                            subtitle: "Emulator cores provided by these projects.",
                            icon: .sfSymbol("square.3.layers.3d.middle.filled"))
            }

            PaidFeatureView {
                NavigationLink(destination: ThemeSelectionView()) {
                    SettingsRow(title: "Theme",
                                value: themeManager.currentPalette.description,
                                icon: .sfSymbol("paintpalette"))
                }
            } lockedView: {
                SettingsRow(title: "Theme",
                            subtitle: "Unlock to change theme.",
                            icon: .sfSymbol("lock.fill"))
            }

            #if !os(tvOS)
            /// App icon selection section
            PaidFeatureView {
                NavigationLink(destination: AppIconSelectorView()) {
                    HStack {
                        Image(systemName: "app")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(.accentColor)
                        Text("Change App Icon")
                        Spacer()
                        IconImage(
                            iconName: iconManager.currentIconName ?? "AppIcon",
                            size: 24
                        )
                    }
                }
            } lockedView: {
                HStack {
                    Image(systemName: "lock.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.accentColor)
                    Text("Change App Icon")
                    Spacer()
                    IconImage(
                        iconName: iconManager.currentIconName ?? "AppIcon",
                        size: 24
                    )
                }
            }
            #endif
        }
    }
}

private struct CoreOptionsSection: View {
    var body: some View {
        Section(header: Text("Core Options")) {
            NavigationLink(destination: CoreOptionsView()) {
                SettingsRow(title: "Core Options",
                            subtitle: "Configure emulator core settings.",
                            icon: .sfSymbol("gearshape.2"))
            }
        }
    }
}

private struct SavesSection: View {

    @Default(.autoSave) var autoSave
    @Default(.timedAutoSaves) var timedAutoSaves
    @Default(.autoLoadSaves) var autoLoadSaves
    @Default(.askToAutoLoad) var askToAutoLoad
    @Default(.timedAutoSaveInterval) var timedAutoSaveInterval

    var timedAutosaveLabelText: String {
        "\(timedAutoSaveInterval/60.0) minutes between timed auto saves."
    }

    var body: some View {
        Section(header: Text("Saves")) {
            ThemedToggle(isOn: $autoSave) {
                SettingsRow(title: "Auto Save",
                            subtitle: "Auto-save game state on close. Must be playing for 30 seconds more.",
                            icon: .sfSymbol("autostartstop"))
            }
            ThemedToggle(isOn: $timedAutoSaves) {
                SettingsRow(title: "Timed Auto Saves",
                            subtitle: "Periodically create save states while you play.",
                            icon: .sfSymbol("clock.badge"))
            }
            ThemedToggle(isOn: $autoLoadSaves) {
                SettingsRow(title: "Auto Load Saves",
                            subtitle: "Automatically load the last save of a game if one exists. Disables the load prompt.",
                            icon: .sfSymbol("autostartstop"))
            }
            ThemedToggle(isOn: $askToAutoLoad) {
                SettingsRow(title: "Ask to Load Saves",
                            subtitle: "Prompt to load last save if one exists. Off always boots from BIOS unless auto load saves is active.",
                            icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark"))
            }
#if !os(tvOS)
            HStack {
                Text("Auto-save Time")
                Slider(value: $timedAutoSaveInterval, in: minutes(1)...minutes(30), step: minutes(1)) {
                    Text("Auto-save Time")
                } minimumValueLabel: {
                    Image(systemName: "hare")
                } maximumValueLabel: {
                    Image(systemName: "tortoise")
                }
            }
            Text(timedAutosaveLabelText)
                .font(.subheadline)
                .foregroundColor(.secondary)
#else
            // TODO: TVOS Selection of autosave time
#endif
        }
    }
}

private struct SocialLinksSection: View {

    let isAppStore: Bool = {
        AppState.shared.isAppStore
    }()

    var body: some View {
        Section(header: Text("Social")) {
            if !isAppStore {
                Link(destination: URL(string: "https://www.patreon.com/provenance")!) {
                    SettingsRow(title: "Patreon",
                                subtitle: "Support us on Patreon.",
                                icon: .named("patreon", PVUIBase.BundleLoader.myBundle))
                }
            }
            Link(destination: URL(string: "https://discord.gg/4TK7PU5")!) {
                SettingsRow(title: "Discord",
                            subtitle: "Join our Discord server for help and community chat.",
                            icon: .named("discord", PVUIBase.BundleLoader.myBundle))
            }
            Link(destination: URL(string: "https://twitter.com/provenanceapp")!) {
                SettingsRow(title: "X",
                            subtitle: "Follow us on X for release and other announcements.",
                            icon: .named("x", PVUIBase.BundleLoader.myBundle))
            }
            if !isAppStore {
                Link(destination: URL(string: "https://www.youtube.com/channel/UCKeN6unYKdayfgLWulXgB1w")!) {
                    SettingsRow(title: "YouTube",
                                subtitle: "Help tutorial videos and new feature previews.",
                                icon: .named("youtube", PVUIBase.BundleLoader.myBundle))
                }
            }
            Link(destination: URL(string: "https://github.com/Provenance-Emu/Provenance")!) {
                SettingsRow(title: "GitHub",
                            subtitle: "Check out GitHub for code, reporting bugs and contributing.",
                            icon: .named("github", PVUIBase.BundleLoader.myBundle))
            }
        }
    }
}

private struct DocumentationSection: View {
    var body: some View {
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
}

private struct BuildSection: View {
    @ObservedObject var viewModel: PVSettingsViewModel

    var body: some View {
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
}

private struct ExtraInfoSection: View {
    var body: some View {
        Section(header: Text("3rd Party & Legal")) {
            /// Open source licenses
            NavigationLink(destination: LicensesView()) {
                SettingsRow(title: "Licenses",
                            subtitle: "Open-source libraries Provenance uses and their respective licenses.",
                            icon: .sfSymbol("doc.text"))
            }
            /// Privacy Policy
            Link(destination: URL(string: "https://provenance-emu.com/privacy/")!) {
                SettingsRow(title: "Privacy Policy",
                            subtitle: nil,
                            icon: .sfSymbol("hand.raised"))
            }
            /// End User License Agreement
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                SettingsRow(title: "End User License Agreement (EULA)",
                            subtitle: nil,
                            icon: .sfSymbol("signature"))
            }
        }
    }
}

private struct AudioSection: View {
    #if !os(tvOS)
    @Default(.volume) var volume
    @Default(.volumeHUD) var volumeHUD
    #endif
    var body: some View {
        Section(header: Text("Audio")) {
            #if !os(tvOS)
            ThemedToggle(isOn: $volumeHUD) {
                SettingsRow(title: "Volume HUD",
                            subtitle: "Show volume indicator when changing volume.",
                            icon: .sfSymbol("speaker.wave.2"))
            }
            HStack {
                Text("Volume")
                Slider(value: $volume, in: 0...1, step: 0.1) {
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
            #endif
            // Add the new navigation link wrapped in PaidFeatureView
            PaidFeatureView {
                NavigationLink(destination: AudioEngineSettingsView()) {
                    SettingsRow(title: "Audio Engine",
                                subtitle: "Configure audio engine, buffer and latency settings.",
                                icon: .sfSymbol("waveform.circle"))
                }
            } lockedView: {
                SettingsRow(title: "Audio Engine",
                            subtitle: "Unlock to configure advanced audio settings.",
                            icon: .sfSymbol("lock.fill"))
            }
        }
    }
}

private struct VideoSection: View {
    @Default(.multiThreadedGL) var multiThreadedGL
    @Default(.multiSampling) var multiSampling
    @Default(.imageSmoothing) var imageSmoothing
    @Default(.showFPSCount) var showFPSCount
    @Default(.nativeScaleEnabled) var nativeScaleEnabled
    @Default(.integerScaleEnabled) var integerScaleEnabled

    var body: some View {
        Section(header: Text("Video")) {
            ThemedToggle(isOn: $multiThreadedGL) {
                SettingsRow(title: "Multi-threaded Rendering",
                            subtitle: "Improves performance but may cause graphical glitches.",
                            icon: .sfSymbol("cpu"))
            }
            ThemedToggle(isOn: $multiSampling) {
                SettingsRow(title: "4X Multisampling GL",
                            subtitle: "Smoother graphics at the cost of performance.",
                            icon: .sfSymbol("square.stack.3d.up"))
            }
            ThemedToggle(isOn: $nativeScaleEnabled) {
                SettingsRow(title: "Native Scaling",
                            subtitle: "Use the original console's resolution.",
                            icon: .sfSymbol("arrow.up.left.and.arrow.down.right"))
            }
            ThemedToggle(isOn: $integerScaleEnabled) {
                SettingsRow(title: "Integer Scaling",
                            subtitle: "Scale by whole numbers only for pixel-perfect display.",
                            icon: .sfSymbol("square.grid.4x3.fill"))
            }
            ThemedToggle(isOn: $imageSmoothing) {
                SettingsRow(title: "Image Smoothing",
                            subtitle: "Smooth scaled graphics. Off for sharp pixels.",
                            icon: .sfSymbol("paintbrush.pointed"))
            }
            ThemedToggle(isOn: $showFPSCount) {
                SettingsRow(title: "FPS Counter",
                            subtitle: "Show frames per second counter.",
                            icon: .sfSymbol("speedometer"))
            }
            NavigationLink(destination: FilterSettingsView()) {
                SettingsRow(title: "Display Filters",
                            subtitle: "Configure CRT and LCD filter effects.",
                            icon: .sfSymbol("tv.fill"))
            }
        }
    }
}

private struct ControllerSection: View {
    @Default(.use8BitdoM30) var use8BitdoM30
    @Default(.pauseButtonIsMenuButton) var pauseButtonIsMenuButton

    var body: some View {
        Group {
            Section(header: Text("Controllers")) {
                NavigationLink(destination: ControllerSettingsView()) {
                    SettingsRow(title: "Controller Selection",
                                subtitle: "Configure external controller mappings.",
                                icon: .sfSymbol("gamecontroller"))
                }
                NavigationLink(destination: ICadeControllerView()) {
                    SettingsRow(title: "iCade / 8Bitdo",
                                subtitle: "Configure iCade and 8Bitdo controller settings.",
                                icon: .sfSymbol("keyboard"))
                }
                ThemedToggle(isOn: $use8BitdoM30) {
                    SettingsRow(title: "Use 8BitDo M30 Mapping",
                                subtitle: "For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the PC Engine",
                                icon: .sfSymbol("arrow.triangle.swap"))
                }
                ThemedToggle(isOn: $pauseButtonIsMenuButton) {
                    SettingsRow(title: "Pause/Menu button opens pause menu",
                                subtitle: "If on, the start/menu button on the controller will open the pause menu in addition to pausing the game",
                                icon: .sfSymbol("pause.rectangle"))
                }
            }
#if !os(tvOS)
            OnScreenControllerSection()
#endif
        }
    }
}

#if !os(tvOS)
private struct OnScreenControllerSection: View {
    @Default(.controllerOpacity) var controllerOpacity
    @Default(.buttonTints) var buttonTints
    @Default(.allRightShoulders) var allRightShoulders
    @Default(.buttonVibration) var buttonVibration
    @Default(.missingButtonsAlwaysOn) var missingButtonsAlwaysOn
    @Default(.onscreenJoypad) var onscreenJoypad
    @Default(.onscreenJoypadWithKeyboard) var onscreenJoypadWithKeyboard

    var body: some View {
        Section(header: Text("On-Screen Controller")) {
            HStack {
                Text("Controller Opacity")
                Slider(value: $controllerOpacity, in: 0...1.0, step: 0.05) {
                    Text("Transparency amount of on-screen controls overlays.")
                } minimumValueLabel: {
                    Image(systemName: "sun.min")
                } maximumValueLabel: {
                    Image(systemName: "sun.max")
                }
            }
            ThemedToggle(isOn: $buttonTints) {
                SettingsRow(title: "Button Colors",
                            subtitle: "Show colored buttons matching original hardware.",
                            icon: .sfSymbol("paintpalette"))
            }
            ThemedToggle(isOn: $allRightShoulders) {
                SettingsRow(title: "All Right Shoulder Buttons",
                            subtitle: "Show all shoulder buttons on the right side.",
                            icon: .sfSymbol("l.joystick.tilt.right"))
            }
            ThemedToggle(isOn: $buttonVibration) {
                SettingsRow(title: "Haptic Feedback",
                            subtitle: "Vibrate when pressing on-screen buttons.",
                            icon: .sfSymbol("hand.point.up.braille"))
            }
            ThemedToggle(isOn: $missingButtonsAlwaysOn) {
                SettingsRow(title: "Missing Buttons Always On",
                            subtitle: "Always show buttons not present on original hardware.",
                            icon: .sfSymbol("l.rectangle.roundedbottom"))
            }

            ThemedToggle(isOn: $onscreenJoypad) {
                SettingsRow(title: "On-Screen Joystick",
                            subtitle: "Show a touch Joystick pad on supported systems.",
                            icon: .sfSymbol("l.joystick.tilt.left.fill"))
            }
            ThemedToggle(isOn: $onscreenJoypadWithKeyboard) {
                SettingsRow(title: "On-Screen Joypad with keyboard",
                            subtitle: "Show a touch Joystick pad on supported systems when the P1 controller is 'Keyboard'. Useful on iPad OS for systems with an analog joystick (N64, PSX, etc.)",
                            icon: .sfSymbol("keyboard.badge.eye"))
            }

        }
    }
}
#endif

private struct LibrarySection: View {
    @ObservedObject var viewModel: PVSettingsViewModel

    var body: some View {
        Section(header: Text("Library")) {
            //#if canImport(PVWebServer)
            //            Button(action: viewModel.launchWebServer) {
            //                SettingsRow(title: "Launch Web Server",
            //                            subtitle: "Transfer ROMs and saves over WiFi.",
            //                            icon: .sfSymbol("xserve"))
            //            }
            //#endif
            NavigationLink(destination: AppearanceView()) {
                SettingsRow(title: "Appearance",
                            subtitle: "Visual options for Game Library",
                            icon: .sfSymbol("eye"))
            }
        }
    }
}

private struct LibrarySection2: View {
    @ObservedObject var viewModel: PVSettingsViewModel

    var body: some View {
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
}

private struct AdvancedSection: View {
    var body: some View {
        Group {
            Section(header: Text("Advanced")) {
                #if canImport(FreemiumKit)
                PaidStatusView(style: .decorative(icon: .star))
                    .listRowBackground(Color.accentColor)
                #endif
                AdvancedTogglesView()
                SecretSettingsRow()
            }
        }
    }
}

private struct FeatureFlagsDebugView: View {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared
    @State private var flags: [(key: String, flag: FeatureFlag, enabled: Bool)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            LoadingSection(isLoading: isLoading, flags: flags)
            FeatureFlagsSection(flags: flags, featureFlags: featureFlags)
            UserDefaultsSection()
            ConfigurationSection()
            DebugControlsSection(featureFlags: featureFlags, flags: $flags, isLoading: $isLoading, errorMessage: $errorMessage)
        }
        .navigationTitle("Feature Flags Debug")
        .task {
            await loadInitialConfiguration()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    @MainActor
    private func loadInitialConfiguration() async {
        isLoading = true

        do {
            // First try to refresh from remote
            try await loadDefaultConfiguration()
            flags = featureFlags.getAllFeatureFlags()
            print("Initial flags loaded: \(flags)")
        } catch {
            errorMessage = "Failed to load remote configuration: \(error.localizedDescription)"
            print("Error loading remote configuration: \(error)")

            // If remote fails, try to refresh from current state
            flags = featureFlags.getAllFeatureFlags()
        }

        isLoading = false
    }

    @MainActor
    private func loadDefaultConfiguration() async throws {
        try await PVFeatureFlagsManager.shared.loadConfiguration(
            from: URL(string: "https://data.provenance-emu.com/features/features.json")!
        )
    }
}

private struct LoadingSection: View {
    let isLoading: Bool
    let flags: [(key: String, flag: FeatureFlag, enabled: Bool)]

    var body: some View {
        if isLoading {
            Section {
                ProgressView("Loading configuration...")
            }
        }
    }
}

private struct FeatureFlagsSection: View {
    let flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    let featureFlags: PVFeatureFlagsManager

    var body: some View {
        Section(header: Text("Feature Flags Status")) {
            if flags.isEmpty {
                Text("No feature flags found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(flags, id: \.key) { flag in
                    FeatureFlagRow(flag: flag, featureFlags: featureFlags)
                }
            }
        }
    }
}

private struct FeatureFlagRow: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    let featureFlags: PVFeatureFlagsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                FeatureFlagInfo(flag: flag)
                Spacer()
                FeatureFlagStatus(flag: flag, featureFlags: featureFlags)
                FeatureFlagToggle(flag: flag, featureFlags: featureFlags)
            }
            FeatureFlagDetails(flag: flag.flag)
        }
        .padding(.vertical, 4)
    }
}

private struct FeatureFlagInfo: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)

    var body: some View {
        VStack(alignment: .leading) {
            Text(flag.key)
                .font(.headline)
            if let description = flag.flag.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct FeatureFlagStatus: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    let featureFlags: PVFeatureFlagsManager

    var body: some View {
        VStack(alignment: .trailing) {
            // Show base configuration state
            Text("Base Config: \(flag.flag.enabled ? "On" : "Off")")
                .font(.caption)
                .foregroundColor(flag.flag.enabled ? .green : .red)

            // Show effective state
            Text("Effective: \(flag.enabled ? "On" : "Off")")
                .font(.caption)
                .foregroundColor(flag.enabled ? .green : .red)

            // Show debug override if present
            if let override = featureFlags.debugOverrides[flag.key] {
                Text("Override: \(override ? "On" : "Off")")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // Show restrictions if any
            let restrictions = featureFlags.getFeatureRestrictions(flag.key)
            if !restrictions.isEmpty {
                ForEach(restrictions, id: \.self) { restriction in
                    Text(restriction)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

private struct FeatureFlagToggle: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    let featureFlags: PVFeatureFlagsManager

    var body: some View {
        Toggle("", isOn: Binding(
            get: {
                featureFlags.debugOverrides[flag.key] ?? flag.enabled
            },
            set: { newValue in
                print("Setting toggle to: \(newValue)")
                featureFlags.setDebugOverride(feature: flag.key, enabled: newValue)
            }
        ))
    }
}

private struct FeatureFlagDetails: View {
    let flag: FeatureFlag

    var body: some View {
        Group {
            if let minVersion = flag.minVersion {
                Text("Min Version: \(minVersion)")
            }
            if let minBuild = flag.minBuildNumber {
                Text("Min Build: \(minBuild)")
            }
            if let allowedTypes = flag.allowedAppTypes {
                Text("Allowed Types: \(allowedTypes.joined(separator: ", "))")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

private struct ConfigurationSection: View {
    var body: some View {
        Section(header: Text("Current Configuration")) {
            Text("App Type: \(PVFeatureFlags.getCurrentAppType().rawValue)")
            Text("App Version: \(PVFeatureFlags.getCurrentAppVersion())")
            if let buildNumber = PVFeatureFlags.getCurrentBuildNumber() {
                Text("Build Number: \(buildNumber)")
            }
            Text("Remote URL: https://data.provenance-emu.com/features/features.json")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct DebugControlsSection: View {
    let featureFlags: PVFeatureFlagsManager
    @Binding var flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    var body: some View {
        Section(header: Text("Debug Controls")) {
            Button("Clear All Overrides") {
                featureFlags.clearDebugOverrides()
                flags = featureFlags.getAllFeatureFlags()
            }

            Button("Refresh Flags") {
                flags = featureFlags.getAllFeatureFlags()
            }

            Button("Load Test Configuration") {
                loadTestConfiguration()
                flags = featureFlags.getAllFeatureFlags()
            }

            Button("Reset to Default") {
                Task {
                    do {
                        // Reset feature flags to default
                        try await loadDefaultConfiguration()
                        flags = featureFlags.getAllFeatureFlags()

                        // Reset unlock status
                        showFeatureFlagsDebug = false

                        // Reset all user defaults to their default values
                        Defaults.Keys.useAppGroups.reset()
                        Defaults.Keys.unsupportedCores.reset()
                        Defaults.Keys.iCloudSync.reset()
                    } catch {
                        errorMessage = "Failed to load default configuration: \(error.localizedDescription)"
                    }
                }
            }
            .foregroundColor(.red) // Make it stand out as a destructive action
        }
    }

    @MainActor
    private func loadTestConfiguration() {
        let testFeatures: [String: FeatureFlag] = [
            "inAppFreeROMs": FeatureFlag(
                enabled: true,
                minVersion: "1.0.0",
                minBuildNumber: "100",
                allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
                description: "Test configuration - enabled for all builds"
            ),
            "romPathMigrator": FeatureFlag(
                enabled: true,
                minVersion: "1.0.0",
                minBuildNumber: "100",
                allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
                description: "Test configuration - enabled for all builds"
            )
        ]

        featureFlags.setDebugConfiguration(features: testFeatures)
    }

    @MainActor
    private func loadDefaultConfiguration() async throws {
        try await PVFeatureFlagsManager.shared.loadConfiguration(
            from: URL(string: "https://data.provenance-emu.com/features/features.json")!
        )
    }
}

private struct AppearanceSection: View {
    @Default(.showGameTitles) var showGameTitles
    @Default(.showRecentGames) var showRecentGames
    @Default(.showRecentSaveStates) var showRecentSaveStates
    @Default(.showGameBadges) var showGameBadges
    @Default(.showFavorites) var showFavorites

    var body: some View {
        Section(header: Text("Appearance")) {
            ThemedToggle(isOn: $showGameTitles) {
                SettingsRow(title: "Show Game Titles",
                            subtitle: "Display game titles under artwork.",
                            icon: .sfSymbol("text.below.photo"))
            }
            ThemedToggle(isOn: $showRecentGames) {
                SettingsRow(title: "Show Recent Games",
                            subtitle: "Display recently played games section.",
                            icon: .sfSymbol("clock"))
            }
            ThemedToggle(isOn: $showRecentSaveStates) {
                SettingsRow(title: "Show Recent Saves",
                            subtitle: "Display recent save states section.",
                            icon: .sfSymbol("clock.badge.checkmark"))
            }
            ThemedToggle(isOn: $showGameBadges) {
                SettingsRow(title: "Show Game Badges",
                            subtitle: "Display badges for favorite and recent games.",
                            icon: .sfSymbol("star.circle"))
            }
            ThemedToggle(isOn: $showFavorites) {
                SettingsRow(title: "Show Favorites",
                            subtitle: "Display favorites section.",
                            icon: .sfSymbol("star"))
            }
        }
    }
}

private struct SecretDPadView: View {
    enum Direction {
        case up, down, left, right
    }

    let onComplete: () -> Void
    @State private var pressedButtons: [Direction] = []
    @State private var showDPad = false
    @Environment(\.dismiss) private var dismiss

    private let konamiCode: [Direction] = [.up, .up, .down, .down, .left, .right, .left, .right]

    var body: some View {
        VStack {
            if showDPad {
                // D-Pad Layout
                VStack(spacing: 0) {
                    // Up button
                    Button(action: { pressButton(.up) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }

                    // Middle row (Left, Right)
                    HStack(spacing: 60) {
                        Button(action: { pressButton(.left) }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                        }

                        Button(action: { pressButton(.right) }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                        }
                    }

                    // Down button
                    Button(action: { pressButton(.down) }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }
                }
                .foregroundColor(.accentColor)

                // Show current sequence
                Text(sequenceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 5) {
            withAnimation {
                showDPad = true
            }
        }
    }

    private var sequenceText: String {
        pressedButtons.map { direction in
            switch direction {
            case .up: return "↑"
            case .down: return "↓"
            case .left: return "←"
            case .right: return "→"
            }
        }.joined(separator: " ")
    }

    private func pressButton(_ direction: Direction) {
        pressedButtons.append(direction)

        // Check if the sequence matches the Konami code
        if pressedButtons.count >= konamiCode.count {
            let lastEight = Array(pressedButtons.suffix(konamiCode.count))
            if lastEight == konamiCode {
                onComplete()
                dismiss()
            }
        }

        // Limit the stored sequence length
        if pressedButtons.count > 16 {
            pressedButtons.removeFirst(8)
        }
    }
}

private struct SecretSettingsRow: View {
    @State private var showSecretView = false
    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    var body: some View {
        Group {
            #if DEBUG
            NavigationLink(destination: FeatureFlagsDebugView()) {
                SettingsRow(title: "Feature Flags Debug",
                           subtitle: "Override feature flags for testing",
                           icon: .sfSymbol("flag.fill"))
            }
            #else
            if showFeatureFlagsDebug {
                NavigationLink(destination: FeatureFlagsDebugView()) {
                    SettingsRow(title: "Feature Flags Debug",
                               subtitle: "Override feature flags for testing",
                               icon: .sfSymbol("flag.fill"))
                }
            } else {
                SettingsRow(title: "About",
                           subtitle: "Version information",
                           icon: .sfSymbol("info.circle"))
                    .onTapGesture {
                        showSecretView = true
                    }
            }
            #endif
        }
        .sheet(isPresented: $showSecretView) {
            SecretDPadView {
                showFeatureFlagsDebug = true
            }
        }
    }
}

private struct UserDefaultsSection: View {
    @Default(.useAppGroups) var useAppGroups
    @Default(.unsupportedCores) var unsupportedCores
    @Default(.iCloudSync) var iCloudSync

    var body: some View {
        Section(header: Text("User Defaults")) {
            UserDefaultToggle(
                title: "useAppGroups",
                subtitle: "Use App Groups for shared storage",
                isOn: $useAppGroups
            )

            UserDefaultToggle(
                title: "unsupportedCores",
                subtitle: "Enable experimental and unsupported cores",
                isOn: $unsupportedCores
            )

            UserDefaultToggle(
                title: "iCloudSync",
                subtitle: "Sync save states and settings with iCloud",
                isOn: $iCloudSync
            )
        }
    }
}

private struct UserDefaultToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isOn)
            }
        }
        .padding(.vertical, 4)
    }
}

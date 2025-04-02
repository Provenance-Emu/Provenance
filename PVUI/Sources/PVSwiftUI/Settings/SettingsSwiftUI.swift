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
import AudioToolbox
import MarkdownView

// Retrowave color extensions
extension Color {
    static let retroPink = Color(red: 0.99, green: 0.11, blue: 0.55)
    static let retroPurple = Color(red: 0.53, green: 0.11, blue: 0.91)
    static let retroBlue = Color(red: 0.0, green: 0.75, blue: 0.95)
    static let retroDarkBlue = Color(red: 0.05, green: 0.05, blue: 0.2)
    static let retroBlack = Color(red: 0.05, green: 0.0, blue: 0.1)
}


#if os(tvOS)
import GameController
#endif

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
            ZStack {
                // Retrowave background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Grid background
                RetroGridForSettings()
                    .edgesIgnoringSafeArea(.all)
                    .opacity(0.3)
                
                // Main content
                ScrollView {
                    VStack(spacing: 16) {
                        // Title with retrowave styling
                        Text("SETTINGS")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                            .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)
                        
                        // Sections
                        VStack(spacing: 16) {
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
            
                            CollapsibleSection(title: "Delta Skins") {
                                DeltaSkinsSection()
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
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true) // Hide default navigation bar
            .overlay(
                // Custom navigation bar
                VStack {
                    HStack {
                        // Done button with retrowave styling
                        Button(action: { dismissAction() }) {
                            Text("DONE")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                        }
                        
                        Spacer()
                        
                        // Help button with retrowave styling
                        Button(action: { viewModel.showHelp() }) {
                            Text("HELP")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

/// Row View for Settings with retrowave styling
struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var icon: SettingsIcon? = nil
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with retrowave styling
            if let icon = icon {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .retroPink.opacity(isHovered ? 0.5 : 0.2), radius: 5)
                    
                    icon.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            
            // Text content with retrowave styling
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.8))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Value with retrowave styling
            if let value = value {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.4))
                    )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .opacity(isHovered ? 1.0 : 0.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
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
    @State private var shouldShowResetButton = false
    @State private var showResetConfirmation = false
    @State private var resetError: String? = nil
    @State private var showConfigEditor = false

    var body: some View {
        Section(header: Text("Core Options")) {
            NavigationLink(destination: CoreOptionsView()) {
                SettingsRow(title: "Core Options",
                            subtitle: "Configure emulator core settings.",
                            icon: .sfSymbol("gearshape.2"))
            }

            if PVFeatureFlagsManager.shared.retroarchBuiltinEditor {
                NavigationLink(destination: RetroArchConfigEditorWrapper()) {
                    SettingsRow(
                        title: "Edit RetroArch Config",
                        subtitle: "Modify advanced RetroArch settings.",
                        icon: .sfSymbol("gearshape.2.fill")
                    )
                }
            }

            if shouldShowResetButton {
                Button(action: { showResetConfirmation = true }) {
                    SettingsRow(title: "Reset RetroArch Config",
                                subtitle: "Restore default RetroArch configuration.",
                                icon: .sfSymbol("arrow.uturn.backward.circle"))
                }
                .uiKitAlert(
                    "Reset RetroArch Config",
                    message: "This will overwrite your current RetroArch configuration with the default settings. Are you sure?",
                    isPresented: $showResetConfirmation,
                    preferredContentSize: CGSize(width: 500, height: 300)
                ) {
                    UIAlertAction(title: "Reset", style: .destructive) { _ in
                        resetRetroArchConfig()
                    }
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        showResetConfirmation = false
                    }
                }
            }

        }
        .task {
            shouldShowResetButton = await PVRetroArchCoreManager.shared.shouldResetConfig()
        }
        .uiKitAlert(
            "Reset Error",
            message: resetError ?? "",
            isPresented: .constant(resetError != nil),
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "OK", style: .default) { _ in
                resetError = nil
            }
        }
    }

    private func resetRetroArchConfig() {
        Task {
            guard let bundledURL = PVRetroArchCoreManager.shared.bundledConfigURL,
                  let activeURL = PVRetroArchCoreManager.shared.activeConfigURL else {
                return
            }

            do {
                try await PVRetroArchCoreManager.shared.copyConfigFile(from: bundledURL, to: activeURL)
                // Update the button state after successful reset
                shouldShowResetButton = await PVRetroArchCoreManager.shared.shouldResetConfig()
            } catch {
                resetError = "Failed to reset RetroArch config: \(error.localizedDescription)"
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
                RetroWaveSlider(value: $timedAutoSaveInterval, 
                               in: minutes(1)...minutes(30), 
                               step: minutes(1),
                               onEditingChanged: { _ in },
                               label: { Text("Auto-save Time") },
                               minimumValueLabel: { Text("1m") },
                               maximumValueLabel: { Text("30m") },
                               leadingIcon: { 
                                   Image(systemName: "hare")
                                       .foregroundColor(RetroTheme.retroBlue)
                               },
                               trailingIcon: { 
                                   Image(systemName: "tortoise")
                                       .foregroundColor(RetroTheme.retroBlue)
                               })
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
    @Default(.respectMuteSwitch) var respectMuteSwitch
    #endif
    var body: some View {
        Section(header: Text("Audio")) {
            #if !os(tvOS)
            ThemedToggle(isOn: $respectMuteSwitch) {
                SettingsRow(title: "Respect Silent Mode",
                            subtitle: respectMuteSwitch ? "Disable game audio when system ringer is muted. Does not apply to headphones or external audio destinations." : "Play game audio when system ringer is muted. Does not apply to headphones or external audio destinations.",
                            icon: respectMuteSwitch ? .sfSymbol("speaker.slash.fill") : .sfSymbol("speaker.slash"))
            }
//            ThemedToggle(isOn: $volumeHUD) {
//                SettingsRow(title: "Volume HUD",
//                            subtitle: "Show volume indicator when changing volume.",
//                            icon: .sfSymbol("speaker.wave.2"))
//            }
            HStack {
                Text("Volume")
                RetroWaveSlider<Float>(value: $volume, 
                                     in: 0...1, 
                                     step: 0.1,
                                     onEditingChanged: { _ in },
                                     label: { Text("Volume Level") },
                                     minimumValueLabel: { Text("") },
                                     maximumValueLabel: { Text("") },
                                     leadingIcon: { 
                                         Image(systemName: "speaker")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     },
                                     trailingIcon: { 
                                         Image(systemName: "speaker.wave.3")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     })
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
    @Default(.hapticFeedback) var hapticFeedback

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
            ThemedToggle(isOn: $hapticFeedback) {
                SettingsRow(title: "Haptic Feedback",
                           subtitle: "Vibrate when pressing buttons.",
                           icon: .sfSymbol("iphone.radiowaves.left.and.right"))
            }
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
    @Default(.buttonSound) var buttonSound
    @Default(.buttonPressEffect) var buttonPressEffect
    @Default(.missingButtonsAlwaysOn) var missingButtonsAlwaysOn
    @Default(.onscreenJoypad) var onscreenJoypad
    @Default(.onscreenJoypadWithKeyboard) var onscreenJoypadWithKeyboard
#if !os(tvOS)
    @Default(.movableButtons) var movableButtons
#endif

    var body: some View {
        Section(header: Text("On-Screen Controller")) {
            HStack {
                Text("Controller Opacity")
                RetroWaveSlider<Double>(value: $controllerOpacity, 
                                     in: 0...1.0, 
                                     step: 0.05,
                                     onEditingChanged: { _ in },
                                     label: { Text("Transparency amount of on-screen controls overlays.") },
                                     minimumValueLabel: { Text("") },
                                     maximumValueLabel: { Text("") },
                                     leadingIcon: { 
                                         Image(systemName: "sun.min")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     },
                                     trailingIcon: { 
                                         Image(systemName: "sun.max")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     })
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
            ThemedToggle(isOn: $movableButtons) {
                SettingsRow(title: "Movable Buttons",
                            subtitle: "Allow player to move on screen controller buttons. Tap with 3-fingers 3 times to toggle.",
                            icon: .sfSymbol("arrow.up.and.down.and.arrow.left.and.right"))
            }

        }
    }

    private func playButtonSound(_ sound: ButtonSound) {
        PVUIBase.ButtonSoundGenerator.shared.playSound(sound, pan: 0, volume: 1.0)
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
        .uiKitAlert(
            "Error",
            message: errorMessage ?? "",
            isPresented: .constant(errorMessage != nil),
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "OK", style: .default) { _ in
                print("OK tapped")
                errorMessage = nil
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
    @ObservedObject var featureFlags: PVFeatureFlagsManager

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
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    @State private var isEnabled: Bool

    init(flag: (key: String, flag: FeatureFlag, enabled: Bool), featureFlags: PVFeatureFlagsManager) {
        self.flag = flag
        self.featureFlags = featureFlags
        // Initialize state with current value
        if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
            _isEnabled = State(initialValue: featureFlags.debugOverrides[feature] ?? flag.enabled)
        } else {
            _isEnabled = State(initialValue: flag.enabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                FeatureFlagInfo(flag: flag)
                Spacer()
                FeatureFlagStatus(flag: flag, featureFlags: featureFlags, isEnabled: isEnabled)
                #if os(tvOS)
                Button(action: {
                    if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
                        isEnabled.toggle()
                        featureFlags.setDebugOverride(feature: feature, enabled: isEnabled)
                    }
                }) {
                    Text(isEnabled ? "On" : "Off")
                        .foregroundColor(isEnabled ? .green : .red)
                }
                #else
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
                            isEnabled = newValue
                            featureFlags.setDebugOverride(feature: feature, enabled: newValue)
                        }
                    }
                ))
                #endif
            }
            FeatureFlagDetails(flag: flag.flag)
        }
        .padding(.vertical, 4)
        .onChange(of: featureFlags.debugOverrides) { _ in
            // Update state when debug overrides change
            if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
                isEnabled = featureFlags.debugOverrides[feature] ?? flag.enabled
            }
        }
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
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .trailing) {
            // Show base configuration state
            Text("Base Config: \(flag.flag.enabled ? "On" : "Off")")
                .font(.caption)
                .foregroundColor(flag.flag.enabled ? .green : .red)

            // Show effective state
            Text("Effective: \(isEnabled ? "On" : "Off")")
                .font(.caption)
                .foregroundColor(isEnabled ? .green : .red)

            // Show debug override if present
            if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key),
               let override = featureFlags.debugOverrides[feature] {
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

            // Add the new navigation link wrapped in PaidFeatureView
            PaidFeatureView {
                NavigationLink(destination: MissingArtworkStyleView()) {
                    SettingsRow(title: "Missing Artwork Style",
                                subtitle: "Choose style for games without artwork.",
                                icon: .sfSymbol("photo.artframe"))
                }
            } lockedView: {
                SettingsRow(title: "Missing Artwork Style",
                            subtitle: "Unlock to customize missing artwork style.",
                            icon: .sfSymbol("lock.fill"))
            }
        }
    }
}

// Add the new view for selecting missing artwork style
private struct MissingArtworkStyleView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Default(.missingArtworkStyle) private var selectedStyle

    var body: some View {
        List {
            ForEach(RetroTestPattern.allCases, id: \.self) { style in
                Button(action: { selectedStyle = style }) {
                    HStack {
                        // Preview of the style
                        Image(uiImage: UIImage.missingArtworkImage(
                            gameTitle: "Preview",
                            ratio: 1.0,
                            pattern: style
                        ))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)

                        // Style description
                        VStack(alignment: .leading) {
                            Text(style.description)
                                .font(.headline)
                            Text(style.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)

                        HomeDividerView()

                        // Selection indicator
                        if selectedStyle == style {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor, lineWidth: 2)
                                .frame(width: 80, height: 80)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Missing Artwork Style")
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
            Button {
                showSecretView = true
            } label: {
                SettingsRow(title: "About",
                           subtitle: "Version information",
                           icon: .sfSymbol("info.circle"))
            }
            .buttonStyle(.plain)
            #else
            if showFeatureFlagsDebug {
                NavigationLink(destination: FeatureFlagsDebugView()) {
                    SettingsRow(title: "Feature Flags Debug",
                               subtitle: "Override feature flags for testing",
                               icon: .sfSymbol("flag.fill"))
                }
            } else {
                Button {
                    showSecretView = true
                } label: {
                    SettingsRow(title: "About",
                               subtitle: "Version information",
                               icon: .sfSymbol("info.circle"))
                }
                .buttonStyle(.plain)
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

private struct SecretDPadView: View {
    enum Direction {
        case up, down, left, right
    }

    let onComplete: () -> Void
    @State private var pressedButtons: [Direction] = []
    @State private var showDPad = false
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    #if os(tvOS)
    @State private var controller: GCController?
    @State private var isHandlingX = false
    @State private var isHandlingY = false
    #endif

    private let konamiCode: [Direction] = [.up, .up, .down, .down, .left, .right, .left, .right]

    var body: some View {
        VStack {
            if showDPad {
                #if os(tvOS)
                // tvOS: Show instructions and handle Siri Remote gestures
                VStack {
                    Text("Use Siri Remote to enter the code")
                        .font(.headline)
                        .padding()

                    // Show current sequence with better visibility
                    Text(sequenceText.isEmpty ? "No input yet" : sequenceText)
                        .font(.title)
                        .foregroundColor(.primary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        )
                        .padding()

                    // Show hint about remaining inputs needed
                    Text("\(konamiCode.count - (pressedButtons.count % konamiCode.count)) more inputs needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #else
                // iOS: Show D-Pad buttons
                VStack(spacing: 0) {
                    Button(action: { pressButton(.up) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }

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

                    Button(action: { pressButton(.down) }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }
                }
                .foregroundColor(.accentColor)

                Text(sequenceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
                #endif
            } else {
                ScrollView {
                    if let markdownPath = Bundle.main.path(forResource: "CONTRIBUTORS", ofType: "md"),
                       let markdown = FileManager.default.contents(atPath: markdownPath) {
                        MarkdownView(text: String(data: markdown, encoding: .utf8) ?? "# CONTRIBUTORS\n\nNo CONTRIBUTORS file found.", baseURL: nil)
                    } else {
                        MarkdownView(text: "# CONTRIBUTORS\n\nNo CONTRIBUTORS file found.", baseURL: nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        #if os(tvOS)
        .focusable()
        .focused($isFocused)
        .onLongPressGesture(minimumDuration: 5) {
            DLOG("[SecretDPadView] Long press detected")
            withAnimation(.easeInOut) {
                showDPad = true
                isFocused = true
                setupController()
            }
        }
        .onChange(of: showDPad) { newValue in
            DLOG("[SecretDPadView] showDPad changed to: \(newValue)")
            if newValue {
                setupController()
            }
        }
        .onChange(of: isFocused) { focused in
            DLOG("[SecretDPadView] Focus changed to: \(focused)")
            if !focused {
                pressedButtons.removeAll()
                removeController()
            } else if showDPad {
                setupController()
            }
        }
        .onDisappear {
            removeController()
        }
        #else
        // iOS: Handle long press gesture
        .onLongPressGesture(minimumDuration: 5) {
            withAnimation {
                showDPad = true
            }
        }
        #endif
    }

    #if os(tvOS)
    private func setupController() {
        DLOG("[SecretDPadView] Setting up controller")
        // Get the first connected controller (Siri Remote)
        controller = GCController.controllers().first

        controller?.microGamepad?.dpad.valueChangedHandler = { [self] dpad, xValue, yValue in
            DLOG("[SecretDPadView] Dpad input - x: \(xValue), y: \(yValue)")

            // Handle X-axis (left/right)
            if xValue == 1.0 && !isHandlingX {
                isHandlingX = true
                pressButton(.right)
            } else if xValue == -1.0 && !isHandlingX {
                isHandlingX = true
                pressButton(.left)
            } else if xValue == 0 {
                isHandlingX = false
            }

            // Handle Y-axis (up/down)
            if yValue == 1.0 && !isHandlingY {
                isHandlingY = true
                pressButton(.up)
            } else if yValue == -1.0 && !isHandlingY {
                isHandlingY = true
                pressButton(.down)
            } else if yValue == 0 {
                isHandlingY = false
            }
        }

        // Enable basic gamepad input profile for Siri Remote
        controller?.microGamepad?.reportsAbsoluteDpadValues = false
    }

    private func removeController() {
        DLOG("[SecretDPadView] Removing controller")
        controller?.microGamepad?.dpad.valueChangedHandler = nil
        controller = nil
        isHandlingX = false
        isHandlingY = false
    }
    #endif

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
        DLOG("[SecretDPadView] Button pressed: \(direction)")
        pressedButtons.append(direction)

        #if os(tvOS)
        // Use AudioServicesPlaySystemSound for tvOS feedback
        AudioServicesPlaySystemSound(1519) // Standard system sound
        #endif

        // Check if the sequence matches the Konami code
        if pressedButtons.count >= konamiCode.count {
            let lastEight = Array(pressedButtons.suffix(konamiCode.count))
            DLOG("[SecretDPadView] Checking sequence: \(lastEight) against \(konamiCode)")
            if lastEight == konamiCode {
                DLOG("[SecretDPadView] Konami code matched!")
                onComplete()
                dismiss()
            }
        }

        // Limit the stored sequence length
        if pressedButtons.count > 16 {
            pressedButtons.removeFirst(8)
        }

        DLOG("[SecretDPadView] Current sequence: \(sequenceText)")
    }
}

private struct DeltaSkinsSection: View {
    @State private var showSystemSkinBrowser = false
    @State private var showDeltaSkinList = false
    @Default(.buttonPressEffect) var buttonPressEffect
    @Default(.buttonSound) var buttonSound

    var body: some View {
        Section {
            // Button to select skins (premium locked)
            PaidFeatureView {
                Button {
                    showSystemSkinBrowser = true
                } label: {
                    SettingsRow(title: "Select Controller Skins",
                              subtitle: "Choose controller skins for each system and orientation.",
                              icon: .sfSymbol("gamecontroller.fill"))
                }
            } lockedView: {
                SettingsRow(title: "Select Controller Skins",
                          subtitle: "Unlock to choose controller skins for each system.",
                          icon: .sfSymbol("lock.fill"))
            }
            
            // Button to manage skins (premium locked)
            PaidFeatureView {
                Button {
                    showDeltaSkinList = true
                } label: {
                    SettingsRow(title: "Manage Controller Skins",
                              subtitle: "View, import, and delete controller skins.",
                              icon: .sfSymbol("folder.badge.gearshape"))
                }
            } lockedView: {
                SettingsRow(title: "Manage Controller Skins",
                          subtitle: "Unlock to manage your controller skins.",
                          icon: .sfSymbol("lock.fill"))
            }
            
            PaidFeatureView {
                buttonSoundEFfect
            } lockedView: {
                SettingsRow(title: "Button Sound Effect",
                            subtitle: "Unlock to select a button sound effect.",
                            icon: .sfSymbol("lock.fill"))
            }
            
            PaidFeatureView {
                buttonTouchFeedback
            } lockedView: {
                SettingsRow(title: "Button Sound Effect",
                            subtitle: "Unlock to select a button sound effect.",
                            icon: .sfSymbol("lock.fill"))
            }
        }
        .sheet(isPresented: $showSystemSkinBrowser) {
            NavigationView {
                SystemSkinBrowserView()
            }
        }
        .sheet(isPresented: $showDeltaSkinList) {
            NavigationView {
                DeltaSkinListView(manager: DeltaSkinManager.shared)
            }
        }
    }
    
    var buttonTouchFeedback: some View {
        // Button Press Effect Picker
        NavigationLink {
            ButtonEffectPickerView(buttonPressEffect: $buttonPressEffect)
        } label: {
            SettingsRow(title: "Button Effect Style",
                       subtitle: buttonPressEffect.description,
                       icon: .sfSymbol("circle.circle"))
        }
    }
    
    var buttonSoundEFfect: some View {
        // Button Sound Effect Picker
        NavigationLink {
            ButtonSoundPickerView(buttonSound: $buttonSound, playSound: playButtonSound)
        } label: {
            SettingsRow(title: "Button Sound Effect",
                        subtitle: buttonSound.description,
                        icon: .sfSymbol("speaker.wave.2"))
        }
    }
    
    
    private func playButtonSound(_ sound: ButtonSound) {
        PVUIBase.ButtonSoundGenerator.shared.playSound(sound, pan: 0, volume: 1.0)
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

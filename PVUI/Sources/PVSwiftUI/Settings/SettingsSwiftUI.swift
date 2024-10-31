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
    var dismissAction: () -> Void  // Add this
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
#if !os(tvOS)
                CollapsibleSection(title: "Audio") {
                    AudioSection()
                }
#endif
                CollapsibleSection(title: "Video") {
                    VideoSection()
                }
                
                CollapsibleSection(title: "Metal") {
                    MetalSection(viewModel: viewModel)
                        .environmentObject(viewModel)
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
                
                CollapsibleSection(title: "Social Links") {
                    SocialLinksSection()
                }
                
                CollapsibleSection(title: "Documentation") {
                    DocumentationSection()
                }
                
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
            .navigationBarItems(
                leading: Button("Done") { dismissAction() },  // Use dismissAction here
                trailing: Button("Help") { viewModel.showHelp() }
            )
        }
        .onAppear {
            viewModel.setupConflictsObserver()
            Task { @MainActor in
                await AppState.shared.libraryUpdatesController?.updateConflicts()
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

// MARK: - Section Views
private struct AppSection: View {
    @ObservedObject var viewModel: PVSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Section(header: Text("App")) {
            NavigationLink(destination: SystemSettingsView()) {
                SettingsRow(title: "Systems",
                            subtitle: "Information on cores, their bioses, links and stats.",
                            icon: .sfSymbol("square.stack.3d.down.forward"))
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
                            icon: .sfSymbol("paintpalette"))
            }
            
            NavigationLink(destination: AppearanceView()) {
                SettingsRow(title: "Appearance",
                            subtitle: "Visual options for Game Library",
                            icon: .sfSymbol("eye"))
            }
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
    var body: some View {
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
            /// Links to projects
            NavigationLink(destination: CoreProjectsView()) {
                SettingsRow(title: "Cores",
                            subtitle: "Emulator cores provided by these projects.",
                            icon: .sfSymbol("square.3.layers.3d.middle.filled"))
            }
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
            Link(destination: URL(string: " https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                SettingsRow(title: "End User License Agreement (EULA)",
                            subtitle: nil,
                            icon: .sfSymbol("signature"))
            }
        }
    }
}

#if !os(tvOS)
private struct AudioSection: View {
    @Default(.volume) var volume
    @Default(.volumeHUD) var volumeHUD
    
    var body: some View {
        Section(header: Text("Audio")) {
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
        }
    }
}
#endif

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
            FiltersSection()
        }
    }
}

private struct FiltersSection: View {
    @Default(.crtFilterEnabled) var crtFilter
    @Default(.lcdFilterEnabled) var lcdFilter
    
    var body: some View {
        Section(header: Text("Filters")) {
            ThemedToggle(isOn: $crtFilter) {
                SettingsRow(title: "CRT Filter",
                            subtitle: "Apply CRT screen effect to games.",
                            icon: .sfSymbol("tv"))
            }
            ThemedToggle(isOn: $lcdFilter) {
                SettingsRow(title: "LCD Filter",
                            subtitle: "Apply LCD screen effect to games.",
                            icon: .sfSymbol("rectangle.on.rectangle"))
            }
        }
    }
}

private struct MetalSection: View {
    @Default(.metalFilter) var metalFilter
    @ObservedObject var viewModel: PVSettingsViewModel
    
    var body: some View {
        Section(header: Text("Metal")) {
            Picker("Metal Filter", selection: $metalFilter) {
                ForEach(viewModel.metalFilters, id: \.self) { filter in
                    Text(filter).tag(filter)
                }
            }
#if !os(tvOS)
            .pickerStyle(.menu)
#endif
        }
    }
}

private struct ControllerSection: View {
    @Default(.use8BitdoM30) var use8BitdoM30
    
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
#if canImport(PVWebServer)
            Button(action: viewModel.launchWebServer) {
                SettingsRow(title: "Launch Web Server",
                            subtitle: "Transfer ROMs and saves over WiFi.",
                            icon: .sfSymbol("xserve"))
            }
#endif
            
            NavigationLink(destination: ConflictsView().environmentObject(viewModel)) {
                SettingsRow(title: "Manage Conflicts",
                            subtitle: "Resolve conflicting save states and files.",
                            value: "\(viewModel.numberOfConflicts)",
                            icon: .sfSymbol("bandage"))
            }
            .disabled(viewModel.numberOfConflicts == 0)
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
            }
        }
    }
}

private struct AdvancedTogglesView: View {
    @Default(.autoJIT) var autoJIT
    @Default(.disableAutoLock) var disableAutoLock
    @Default(.iCloudSync) var iCloudSync
    @Default(.useMetal) var useMetalRenderer
    @Default(.useUIKit) var useUIKit
    @Default(.webDavAlwaysOn) var webDavAlwaysOn
    @Default(.unsupportedCores) var unsupportedCores
    @Default(.monoAudio) var monoAudio
    @Default(.useLegacyAudioEngine) var useLegacyAudioEngine
#if !os(tvOS)
    @Default(.movableButtons) var movableButtons
#endif
    
    /// Check if the app is from the App Store
    let isAppStore: Bool = {
        Bundle.main.infoDictionary?["ALTDeviceID"] != nil
    }()
    
    var body: some View {
        
        Group {
            if !isAppStore {
                PremiumThemedToggle(isOn: $autoJIT) {
                    SettingsRow(title: "Auto JIT",
                                subtitle: "Automatically enable JIT when available.",
                                icon: .sfSymbol("bolt"))
                }
            }
            
            PremiumThemedToggle(isOn: $disableAutoLock) {
                SettingsRow(title: "Disable Auto Lock",
                            subtitle: "Prevent device from auto-locking during gameplay.",
                            icon: .sfSymbol("lock.open"))
            }
            
            if !isAppStore {
                PremiumThemedToggle(isOn: $iCloudSync) {
                    SettingsRow(title: "iCloud Sync",
                                subtitle: "Sync save states and settings across devices.",
                                icon: .sfSymbol("icloud"))
                }
            }
            
            PremiumThemedToggle(isOn: $useMetalRenderer) {
                SettingsRow(title: "Metal Renderer",
                            subtitle: "Use Metal for improved graphics performance.",
                            icon: .sfSymbol("cpu"))
            }
            
            PremiumThemedToggle(isOn: $useUIKit) {
                SettingsRow(title: "Use UIKit",
                            subtitle: "Use UIKit interface instead of SwiftUI.",
                            icon: .sfSymbol("switch.2"))
            }
            
            //             PremiumThemedToggle(isOn: $monoAudio) {
            //                 SettingsRow(title: "Mono Audio",
            //                            subtitle: "Combine left and right audio channels.",
            //                            icon: .sfSymbol("speaker.wave.1"))
            //             }
#if !os(tvOS)
            PremiumThemedToggle(isOn: $movableButtons) {
                SettingsRow(title: "Movable Buttons",
                            subtitle: "Allow player to move on screen controller buttons. Tap with 3-fingers 3 times to toggle.",
                            icon: .sfSymbol("arrow.up.and.down.and.arrow.left.and.right"))
            }
#endif
            
            //             PremiumThemedToggle(isOn: $useLegacyAudioEngine) {
            //                 SettingsRow(title: "Legacy Audio",
            //                            subtitle: "Use legacy audio engine for compatibility.",
            //                            icon: .sfSymbol("waveform"))
            //             }
            
            PremiumThemedToggle(isOn: $webDavAlwaysOn) {
                SettingsRow(title: "WebDAV Always On",
                            subtitle: "Keep WebDAV server running in background.",
                            icon: .sfSymbol("network"))
            }
            
            if !isAppStore {
                PremiumThemedToggle(isOn: $unsupportedCores) {
                    SettingsRow(title: "Show Unsupported Cores",
                                subtitle: "Display experimental and unsupported cores.",
                                icon: .sfSymbol("exclamationmark.triangle"))
                }
            }
        }
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

private struct CollapsibleSection<Content: View>: View {
    let title: String
    let content: Content
    @Default(.collapsedSections) var collapsedSections
    @State private var isExpanded: Bool
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self._isExpanded = State(initialValue: !Defaults[.collapsedSections].contains(title))
        print("Init CollapsibleSection '\(title)' - collapsed sections: \(Defaults[.collapsedSections])")
    }
    
    var body: some View {
        Section {
            if isExpanded {
                content
            }
        } header: {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                    print("Setting isExpanded for '\(title)' to \(isExpanded)")
                    print("Before - collapsed sections: \(collapsedSections)")
                    if isExpanded {
                        collapsedSections.remove(title)
                    } else {
                        collapsedSections.insert(title)
                    }
                    print("After - collapsed sections: \(collapsedSections)")
                }
            }) {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

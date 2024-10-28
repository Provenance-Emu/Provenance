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
    /// View model for managing settings state and logic
    @StateObject private var viewModel = PVSettingsViewModel()
    /// Environment variable for dismissing the view
    @Environment(\.dismiss) private var dismiss

    /// Theme manager
    @ObservedObject private var themeManager = ThemeManager.shared

#if canImport(FreemiumKit)
    @State var showPaywall: Bool = false
    @EnvironmentObject var freemiumKit: FreemiumKit
#endif

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
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                },
                trailing: Button("Help") {
                    viewModel.showHelp()
                }
            )
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
            ThemedToggle(isOn: $viewModel.autoSave) {
                SettingsRow(title: "Auto Save", subtitle: "Auto-save game state on close. Must be playing for 30 seconds more.", icon: .sfSymbol("autostartstop"))
            }
            ThemedToggle(isOn: $viewModel.timedAutoSaves) {
                SettingsRow(title: "Timed Auto Saves", subtitle: "Periodically create save states while you play.", icon: .sfSymbol("clock.badge"))
            }
            ThemedToggle(isOn: $viewModel.autoLoadSaves) {
                SettingsRow(title: "Auto Load Saves", subtitle: "Automatically load the last save of a game if one exists. Disables the load prompt.", icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark"))
            }
            ThemedToggle(isOn: $viewModel.askToAutoLoad) {
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
            ThemedToggle(isOn: $viewModel.volumeHUD) {
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
            ThemedToggle(isOn: $viewModel.multiThreadedGL) {
                SettingsRow(title: "Multi-threaded Rendering",
                           subtitle: "Improves performance but may cause graphical glitches.",
                            icon: .sfSymbol("cpu"))
            }
            ThemedToggle(isOn: $viewModel.multiSampling) {
                SettingsRow(title: "4X Multisampling GL",
                           subtitle: "Smoother graphics at the cost of performance.",
                           icon: .sfSymbol("square.stack.3d.up"))
            }
            ThemedToggle(isOn: $viewModel.nativeScaleEnabled) {
                SettingsRow(title: "Native Scaling",
                           subtitle: "Use the original console's resolution.",
                           icon: .sfSymbol("arrow.up.left.and.arrow.down.right"))
            }
            ThemedToggle(isOn: $viewModel.integerScaleEnabled) {
                SettingsRow(title: "Integer Scaling",
                           subtitle: "Scale by whole numbers only for pixel-perfect display.",
                           icon: .sfSymbol("square.grid.4x3.fill"))
            }
            ThemedToggle(isOn: $viewModel.imageSmoothing) {
                SettingsRow(title: "Image Smoothing",
                           subtitle: "Smooth scaled graphics. Off for sharp pixels.",
                           icon: .sfSymbol("paintbrush.pointed"))
            }
            ThemedToggle(isOn: $viewModel.showFPSCount) {
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
            ThemedToggle(isOn: $viewModel.crtFilterEnabled) {
                SettingsRow(title: "CRT Filter",
                           subtitle: "Apply CRT screen effect to games.",
                           icon: .sfSymbol("tv"))
            }
            ThemedToggle(isOn: $viewModel.lcdFilterEnabled) {
                SettingsRow(title: "LCD Filter",
                           subtitle: "Apply LCD screen effect to games.",
                           icon: .sfSymbol("rectangle.on.rectangle"))
            }
        }
    }

    /// Section for metal settings
    var metalSection: some View {
        Section(header: Text("Metal")) {
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
            ThemedToggle(isOn: $viewModel.buttonTints) {
                SettingsRow(title: "Button Colors",
                           subtitle: "Show colored buttons matching original hardware.",
                           icon: .sfSymbol("paintpalette"))
            }
            ThemedToggle(isOn: $viewModel.allRightShoulders) {
                SettingsRow(title: "All Right Shoulder Buttons",
                           subtitle: "Show all shoulder buttons on the right side.",
                           icon: .sfSymbol("l.joystick.tilt.right"))
            }
            ThemedToggle(isOn: $viewModel.buttonVibration) {
                SettingsRow(title: "Haptic Feedback",
                           subtitle: "Vibrate when pressing on-screen buttons.",
                           icon: .sfSymbol("hand.point.up.braille"))
            }
            ThemedToggle(isOn: $viewModel.missingButtonsAlwaysOn) {
                SettingsRow(title: "Missing Buttons Always On",
                           subtitle: "Always show buttons not present on original hardware.",
                           icon: .sfSymbol("l.rectangle.roundedbottom"))
            }
        }
    }

    // Section for library settings
    var librarySection: some View {
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
        Group {
            Section(header: Text("Advanced")) {
#if canImport(FreemiumKit)
                PaidStatusView(style: .decorative(icon: .star))
                    .listRowBackground(Color.accentColor)
//                    .padding(.vertical, -10)
#endif
                advancedToggles
            }
//#if canImport(FreemiumKit)
//            Section {
//                PaidStatusView(style: .decorative(icon: .laurel))
//                    .listRowBackground(Color.accentColor)
//                    .padding(.vertical, -10)
//            }
//#endif
        }
    }

    /// Toggles for Advanced setting section
    var advancedToggles: some View {
        Group {
            PremiumThemedToggle(isOn: $viewModel.useMetalRenderer) {
                SettingsRow(title: "Use Metal Renderer",
                           subtitle: "Modern graphics API for better performance.",
                           icon: .sfSymbol("m.square.fill"))
            }
            PremiumThemedToggle(isOn: $viewModel.useUIKit) {
                SettingsRow(title: "Use Legacy UIKit UI",
                           subtitle: "Switch to classic interface. Requires app restart.",
                           icon: .sfSymbol("swift"))
            }
            PremiumThemedToggle(isOn: $viewModel.movableButtons) {
                SettingsRow(title: "Movable Buttons",
                           subtitle: "Allow moving on-screen buttons. Triple-tap with three fingers to ThemedToggle.",
                           icon: .sfSymbol("arrow.up.and.down.and.arrow.left.and.right"))
            }
            PremiumThemedToggle(isOn: $viewModel.onscreenJoypad) {
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

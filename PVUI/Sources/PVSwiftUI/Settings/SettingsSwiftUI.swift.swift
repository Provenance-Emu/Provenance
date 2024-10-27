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

public struct PVSettingsView: View {
    // View model for managing settings state and logic
    @StateObject private var viewModel = PVSettingsViewModel()
    // Environment variable for dismissing the view
    @Environment(\.presentationMode) var presentationMode

    public var body: some View {
        NavigationView {
            List {
                appSection
                coreOptionsSection
                savesSection
                avSection
                metalSection
                controllerSection
                librarySection
                librarySection2
                betaSection
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
            viewModel.setupConflictsObserver()
        }
    }

    // Section for app-related settings
    var appSection: some View {
        Section(header: Text("App")) {
            NavigationLink(destination: SystemSettingsView()) {
                SettingsRow(title: "Systems", subtitle: "Information on cores, their bioses, links and stats.", icon: "square.stack")
            }
            Button(action: viewModel.showThemeOptions) {
                SettingsRow(title: "Theme", value: viewModel.currentTheme, icon: "paintbrush")
            }
            Toggle("Auto Load Saves", isOn: $viewModel.autoLoadSaves)
            Toggle("Auto Save", isOn: $viewModel.autoSave)
            NavigationLink(destination: GameLibraryView()) {
                SettingsRow(title: "Game Library", icon: "books.vertical")
            }
        }
    }

    // Section for core options settings
    var coreOptionsSection: some View {
        Section(header: Text("Core Options")) {
            NavigationLink(destination: CoreOptionsView()) {
                SettingsRow(title: "Core Options", icon: "gearshape.2")
            }
        }
    }

    // Section for saves settings
    var savesSection: some View {
        Section(header: Text("Saves")) {
            Toggle("iCloud Sync", isOn: $viewModel.iCloudSync)
            Toggle("Ask to Sync", isOn: $viewModel.askToSync)
        }
    }

    // Section for audio/video settings
    var avSection: some View {
        Section(header: Text("Audio / Video")) {
            Toggle("Smooth Scaling", isOn: $viewModel.smoothScaling)
            Toggle("CRT Filter", isOn: $viewModel.crtFilter)
            Toggle("Sound", isOn: $viewModel.sound)
        }
    }

    // Section for metal settings
    var metalSection: some View {
        Section(header: Text("Metal")) {
            Toggle("Use Metal Renderer", isOn: $viewModel.useMetalRenderer)
        }
    }

    // Section for controller settings
    var controllerSection: some View {
        Section(header: Text("Controller")) {
            NavigationLink(destination: ControllerSettingsView()) {
                SettingsRow(title: "Controller Settings", icon: "gamecontroller")
            }
        }
    }

    // Section for library settings
    var librarySection: some View {
        Section(header: Text("Library")) {
            Button(action: viewModel.reimportROMs) {
                SettingsRow(title: "Re-import ROMs", icon: "arrow.clockwise")
            }
            Button(action: viewModel.resetData) {
                SettingsRow(title: "Reset Data", icon: "trash")
            }
            Button(action: viewModel.refreshGameLibrary) {
                SettingsRow(title: "Refresh Game Library", icon: "arrow.triangle.2.circlepath")
            }
        }
    }

    // Section for library settings
    var librarySection2: some View {
        Section(header: Text("Library")) {
            Button(action: viewModel.emptyImageCache) {
                SettingsRow(title: "Empty Image Cache", icon: "photo.on.rectangle.angled")
            }
            NavigationLink(destination: ConflictsView()) {
                SettingsRow(title: "Manage Conflicts", value: "\(viewModel.numberOfConflicts)", icon: "exclamationmark.triangle")
            }
        }
    }

    // Section for beta settings
    var betaSection: some View {
        Section(header: Text("Beta")) {
            Toggle("Beta Features", isOn: $viewModel.betaFeatures)
        }
    }

    // Section for social links
    var socialLinksSection: some View {
        Section(header: Text("Social")) {
            Link(destination: URL(string: "https://discord.gg/4TK7PU5")!) {
                SettingsRow(title: "Discord", icon: "bubble.left.and.bubble.right")
            }
            Link(destination: URL(string: "https://twitter.com/provenanceapp")!) {
                SettingsRow(title: "Twitter", icon: "bird")
            }
            Link(destination: URL(string: "https://github.com/Provenance-Emu/Provenance")!) {
                SettingsRow(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    // Section for documentation
    var documentationSection: some View {
        Section(header: Text("Documentation")) {
            Link(destination: URL(string: "https://wiki.provenance-emu.com")!) {
                SettingsRow(title: "Wiki", icon: "book")
            }
        }
    }

    // Section for build information
    var buildSection: some View {
        Section(header: Text("Build")) {
            SettingsRow(title: "Build Date", value: viewModel.buildDate)
            SettingsRow(title: "Git Rev", value: viewModel.gitRev)
        }
    }

    // Section for displaying extra information
    var extraInfoSection: some View {
        Section(header: Text("3rd Party & Legal")) {
            NavigationLink(destination: CoreProjectsView()) {
                SettingsRow(title: "Core Projects", subtitle: "Emulator cores provided by these projects.", icon: "square.3.layers.3d.middle.filled")
            }
            NavigationLink(destination: LicensesView()) {
                SettingsRow(title: "Licenses", subtitle: "Open-source libraries Provenance uses and their respective licenses.", icon: "mail.stack.fill")
            }
        }
    }
}

struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
            }
            VStack(alignment: .leading) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let value = value {
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
}

class PVSettingsViewModel: ObservableObject {
    // Published property for auto load saves setting
    @Default(.autoLoadSaves) var autoLoadSaves
    // Published property for auto save setting
    @Published var autoSave: Bool = Defaults[.autoSave]
    // Published property for current theme
    @Published var currentTheme: String = Defaults[.theme].description
    // Published property for number of conflicts
    @Published var numberOfConflicts: Int = 0
    // Published property for iCloud sync
    @Published var iCloudSync: Bool = Defaults[.iCloudSync]
    // Published property for ask to sync
    @Published var askToSync: Bool = Defaults[.askToSync]
    // Published property for smooth scaling
    @Published var smoothScaling: Bool = Defaults[.smoothScaling]
    // Published property for CRT filter
    @Published var crtFilter: Bool = Defaults[.crtFilter]
    // Published property for sound
    @Published var sound: Bool = Defaults[.sound]
    // Published property for use metal renderer
    @Published var useMetalRenderer: Bool = Defaults[.useMetalRenderer]
    // Published property for beta features
    @Published var betaFeatures: Bool = Defaults[.betaFeatures]

    // Set to store cancellable objects
    private var cancellables = Set<AnyCancellable>()
    // Reachability instance for network connectivity
    private let reachability: Reachability = try! Reachability()

    // Computed property to get app version
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    // Computed property to get build version
    var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    // Computed property to get build date
    var buildDate: String {
        // Implement build date retrieval
        "Unknown"
    }

    // Computed property to get git revision
    var gitRev: String {
        // Implement git revision retrieval
        "Unknown"
    }

    // Function to setup conflicts observer
    func setupConflictsObserver() {
        // Implement conflicts observer
    }

    // Function to show theme options
    func showThemeOptions() {
        // Implement theme options presentation
    }

    // Function to show help
    func showHelp() {
        // Implement help presentation
    }

    // Function to reimport ROMs
    func reimportROMs() {
        // Implement ROM reimport functionality
    }

    // Function to reset data
    func resetData() {
        // Implement data reset functionality
    }

    // Function to refresh game library
    func refreshGameLibrary() {
        // Implement game library refresh functionality
    }

    // Function to empty image cache
    func emptyImageCache() {
        // Implement image cache emptying functionality
    }
}

struct SystemSettingsView: View {
    // Body of the SystemSettingsView
    var body: some View {
        Text("System Settings")
    }
}

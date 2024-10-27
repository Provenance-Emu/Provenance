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

// MARK: - PVSettingsView
public struct PVSettingsView: View {
    // View model for managing settings state and logic
    @StateObject private var viewModel = PVSettingsViewModel()
    // Environment variable for dismissing the view
    @Environment(\.presentationMode) var presentationMode

    let conflictsController: PVGameLibraryUpdatesController

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
            viewModel.conflictsController = conflictsController
        }
    }

    // Section for app-related settings
    var appSection: some View {
        Section(header: Text("App")) {
            NavigationLink(destination: SystemSettingsView()) {
                SettingsRow(title: "Systems", subtitle: "Information on cores, their bioses, links and stats.", icon: "square.stack")
            }
            Button(action: viewModel.showThemeOptions) {
                SettingsRow(title: "Theme", value: viewModel.currentTheme.description, icon: "paintbrush")
            }
            NavigationLink(destination: AppearanceView()) {
                SettingsRow(title: "Appearance", icon: "paintpalette")
            }
            Toggle("Auto Load Saves", isOn: $viewModel.autoLoadSaves)
            Toggle("Auto Save", isOn: $viewModel.autoSave)
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
            Toggle(isOn: $viewModel.autoSave) {
                SettingsRow(title: "Auto Save", subtitle: "Auto-save game state on close. Must be playing for 30 seconds more.", icon: "autostartstop")
            }
            Toggle(isOn: $viewModel.timedAutoSaves) {
                SettingsRow(title: "Timed Auto Saves", subtitle: "Periodically create save states while you play.", icon: "clock.badge")
            }
            Toggle(isOn: $viewModel.autoLoadSaves) {
                SettingsRow(title: "Auto Load Saves", subtitle: "Automatically load the last save of a game if one exists. Disables the load prompt.", icon: "autostartstop.trianglebadge.exclamationmark")
            }
            Toggle(isOn: $viewModel.askToAutoLoad) {
                SettingsRow(title: "Ask to Load Saves", subtitle: "Prompt to load last save if one exists. Off always boots from BIOS unless auto load saves is active.", icon: "autostartstop.trianglebadge.exclamationmark")
            }

            #if os(iOS)
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
            #endif
        }
    }

    // Section for audio/video settings
    var avSection: some View {
        Section(header: Text("Audio / Video")) {
            Toggle("4x Multi Scaling", isOn: $viewModel.multiSampling)
            Toggle("CRT Filter", isOn: $viewModel.crtFilter)
            Toggle("Volume HUD", isOn: $viewModel.volumeHUD)
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
            NavigationLink(destination: ICadeControllerView()) {
                SettingsRow(title: "iCade / 8Bitdo", icon: "gamecontroller.fill")
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
            NavigationLink(destination: ConflictsView().environmentObject(viewModel)) {
                SettingsRow(title: "Manage Conflicts", value: "\(viewModel.numberOfConflicts)", icon: "exclamationmark.triangle")
            }
        }
    }

    // Section for beta settings
    var betaSection: some View {
        Section(header: Text("Beta")) {
//            Toggle("Beta Features", isOn: $viewModel.betaFeatures)
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
    @Default(.autoLoadSaves) var autoLoadSaves
    @Default(.autoSave) var autoSave
    @Default(.theme) var currentTheme
    @Published var numberOfConflicts: Int = 0
    @Default(.iCloudSync) var iCloudSync
    @Default(.integerScaleEnabled) var integerScaleEnabled
    @Default(.crtFilterEnabled) var crtFilter
    @Default(.lcdFilterEnabled) var lcdFilter
    @Default(.metalFilter) var metalFilter
    @Default(.useMetal) var useMetalRenderer
    @Default(.disableAutoLock) var disableAutoLock
    @Default(.multiSampling) var multiSampling
    @Default(.volumeHUD) var volumeHUD
    @Default(.timedAutoSaves) var timedAutoSaves
    @Default(.askToAutoLoad) var askToAutoLoad
    @Default(.timedAutoSaveInterval) var timedAutoSaveInterval

//    @ObservedObject
    var conflictsController: PVGameLibraryUpdatesController! {
        didSet {
            setupConflictsObserver()
        }
    }

    private var cancellables = Set<AnyCancellable>()
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
    public func setupConflictsObserver() {
//        conflictsController?.$conflicts
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] conflicts in
//                self?.numberOfConflicts = conflicts.count
//            }
//            .store(in: &cancellables)
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

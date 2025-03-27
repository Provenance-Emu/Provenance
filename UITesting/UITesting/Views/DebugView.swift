//
//  DebugView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes
import PVUIBase
import PVLibrary
import PVRealm
import RealmSwift
import PVLogging

// Add this enum at the top of your file or in a separate extension
enum ThemeName: String, CaseIterable {
    case `default` = "Default"
    case dark = "Dark"
    case light = "Light"
    // CGA Themes
    case cgaBlue = "CGA Blue"
    case cgaCyan = "CGA Cyan"
    case cgaGreen = "CGA Green"
    case cgaMagenta = "CGA Magenta"
    case cgaRed = "CGA Red"
    case cgaYellow = "CGA Yellow"
    case cgaPurple = "CGA Purple"
    case cgaRainbow = "CGA Rainbow"
}

struct DebugView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState

    // Debug state
    @State private var showDatabaseStats = false
    @State private var showImportQueue = false
    @State private var showConfirmResetAlert = false

    // Mock importer for testing
    @StateObject private var mockImportStatusDriverData = MockImportStatusDriverData()

    // Add these state variables at the top of the DebugView struct
    @State private var showSaveStatesMock = false
    @State private var showGameMoreInfo = false
    @State private var showGameMoreInfoRealm = false
    @State private var showArtworkSearch = false

    // Add these additional state variables
    @State private var showFreeROMs = false
    @State private var showDeltaSkinList = false
    @State private var selectedTheme: ThemeName = .default

    // Add this new state variable
    @State private var showDeltaSkinImport = false
    @State private var showDeltaSkinPreview = false

    var body: some View {
        NavigationView {
            List {
                Section("Database") {
                    Button("View Database Stats") {
                        showDatabaseStats = true
                    }

                    Button("Reset Database") {
                        showConfirmResetAlert = true
                    }
                    .foregroundColor(.red)

                    NavigationLink("Browse Games", destination: DatabaseBrowserView())
                }


                Section("Import") {
                    Button("Show Import Queue") {
                        showImportQueue = true
                    }

                    Button("Force Import Scan") {
                        // Force a scan of the import directories
                        appState.gameImporter?.startProcessing()
                    }

                    Button("Install Test ROM") {
                        // Install the test ROM
                        Task {
                            do {
                                try await installTestROM()
                            } catch {
                                ELOG("Error installing test ROM: \(error)")
                            }
                        }
                    }
                }

                Section("UI Testing") {
                    NavigationLink("Theme Preview", destination: ThemePreviewView())

                    Button("Show Save States UI") {
                        showSaveStatesMock = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.blue, .purple]))

                    Button("Show Game Info UI") {
                        showGameMoreInfo = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.green, .blue]))

                    Button("Show Game Info (Realm)") {
                        showGameMoreInfoRealm = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.orange, .red]))

                    Button("Show Artwork Search") {
                        showArtworkSearch = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.pink, .purple]))

                    Button("Show Free ROMs") {
                        showFreeROMs = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.yellow, .orange]))

                    Button("Show Delta Skin List") {
                        showDeltaSkinList = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.mint, .teal]))
                }

                // Add this section for theme testing
                Section("Theme Testing") {
                    Picker("Select Theme", selection: $selectedTheme) {
                        ForEach(ThemeName.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .onChange(of: selectedTheme) { newValue in
                        applyTheme(newValue)
                    }

                    ColorPalettePreview(palette: themeManager.currentPalette)
                }

                // Add this new section
                Section("Controller Skins") {
                    NavigationLink("Browse System Skins", destination: SystemSkinBrowserView())

                    Button("Import Skin") {
                        showDeltaSkinImport = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.purple, .blue]))

                    Button("Test Skin Preview") {
                        showDeltaSkinPreview = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.blue, .green]))
                }
            }
            .navigationTitle("Debug")
            .alert(isPresented: $showConfirmResetAlert) {
                Alert(
                    title: Text("Reset Database"),
                    message: Text("This will delete all games and save states. This action cannot be undone."),
                    primaryButton: .destructive(Text("Reset")) {
                        resetDatabase()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showDatabaseStats) {
                DatabaseStatsView()
            }
            .sheet(isPresented: $showImportQueue) {
                ImportStatusView(
                    updatesController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                    gameImporter: mockImportStatusDriverData.gameImporter,
                    delegate: mockImportStatusDriverData) {
                        showImportQueue = false
                    }
            }
            .sheet(isPresented: $showSaveStatesMock) {
                SaveStatesMockView()
            }
            .sheet(isPresented: $showGameMoreInfo) {
                NavigationView {
                    let driver = MockGameLibraryDriver()
                    PagedGameMoreInfoView(viewModel: PagedGameMoreInfoViewModel(driver: driver))
                        .navigationTitle("Game Info")
                }
            }
            .sheet(isPresented: $showGameMoreInfoRealm) {
                if let driver = try? RealmGameLibraryDriver.previewDriver() {
                    NavigationView {
                        PagedGameMoreInfoView(viewModel: PagedGameMoreInfoViewModel(driver: driver))
                            .navigationTitle("Game Info")
                    }
                }
            }
            .sheet(isPresented: $showArtworkSearch) {
                NavigationView {
                    ArtworkSearchView { selection in
                        print("Selected artwork: \(selection.metadata.url)")
                        showArtworkSearch = false
                    }
                    .navigationTitle("Artwork Search")
                    #if !os(tvOS)
                    .background(Color(uiColor: .systemBackground))
                    #endif
                }
                #if !os(tvOS)
                .presentationBackground(Color(uiColor: .systemBackground))
                #endif
            }
            .sheet(isPresented: $showFreeROMs) {
                FreeROMsView { rom, url in
                    print("Downloaded ROM: \(rom.file) to: \(url)")
                    showFreeROMs = false
                }
            }
            .sheet(isPresented: $showDeltaSkinList) {
                NavigationView {
                    DeltaSkinListView(manager: DeltaSkinManager.shared)
                }
            }
            .sheet(isPresented: $showDeltaSkinImport) {
                DeltaSkinImportView()
            }
            .sheet(isPresented: $showDeltaSkinPreview) {
                DeltaSkinPreviewWrapper()
            }
        }
    }

    // Reset the Realm database
    private func resetDatabase() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.deleteAll()
            }
            ILOG("Database reset successfully")
        } catch {
            ELOG("Error resetting database: \(error)")
        }
    }

    // Install the test ROM
    private func installTestROM() async throws {
        // Get the path to the test ROM in the app bundle
        guard let testROMURL = Bundle.main.url(forResource: "240p", withExtension: "nes") else {
            throw NSError(domain: "UITestingApp", code: 3, userInfo: [NSLocalizedDescriptionKey: "Test ROM not found in app bundle"])
        }

        // Get the Documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "UITestingApp", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not access Documents directory"])
        }

        // Create the ROMs/com.provenance.nes directory if it doesn't exist
        let romsDirectoryURL = documentsURL.appendingPathComponent("ROMs/com.provenance.nes", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: romsDirectoryURL, withIntermediateDirectories: true)
            ILOG("Created ROMs directory at: \(romsDirectoryURL.path)")
        } catch {
            ELOG("Error creating ROMs directory: \(error)")
            throw error
        }

        // Define the destination URL for the ROM
        let destinationURL = romsDirectoryURL.appendingPathComponent("240p-test.nes")

        // Check if the ROM already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            ILOG("ROM already exists at destination, skipping copy")
            return
        }

        // Copy the ROM to the ROMs directory
        do {
            try FileManager.default.copyItem(at: testROMURL, to: destinationURL)
            ILOG("Successfully copied ROM to: \(destinationURL.path)")
            appState.gameImporter?.startProcessing()
        } catch {
            ELOG("Error copying ROM: \(error)")
            throw error
        }

        // Resume the importer to process the new ROM
        appState.gameImporter?.resume()
    }

    // Add this helper method to apply the selected theme
    private func applyTheme(_ theme: ThemeName) {
        switch theme {
        case .default:
            ThemeManager.shared.setCurrentPalette(ProvenanceThemes.default.palette)
        case .dark:
            ThemeManager.shared.setCurrentPalette(ProvenanceThemes.dark.palette)
        case .light:
            ThemeManager.shared.setCurrentPalette(ProvenanceThemes.light.palette)
        case .cgaBlue:
            ThemeManager.shared.setCurrentPalette(CGAThemes.blue.palette)
        case .cgaCyan:
            ThemeManager.shared.setCurrentPalette(CGAThemes.cyan.palette)
        case .cgaGreen:
            ThemeManager.shared.setCurrentPalette(CGAThemes.green.palette)
        case .cgaMagenta:
            ThemeManager.shared.setCurrentPalette(CGAThemes.magenta.palette)
        case .cgaRed:
            ThemeManager.shared.setCurrentPalette(CGAThemes.red.palette)
        case .cgaYellow:
            ThemeManager.shared.setCurrentPalette(CGAThemes.yellow.palette)
        case .cgaPurple:
            ThemeManager.shared.setCurrentPalette(CGAThemes.purple.palette)
        case .cgaRainbow:
            ThemeManager.shared.setCurrentPalette(CGAThemes.rainbow.palette)
        }
    }
}

// MARK: - Database Stats View

struct DatabaseStatsView: View {
    @Environment(\.presentationMode) var presentationMode

    // Database stats
    @State private var gameCount = 0
    @State private var systemCount = 0
    @State private var coreCount = 0
    @State private var saveStateCount = 0

    var body: some View {
        NavigationView {
            List {
                Section("Counts") {
                    StatRow(title: "Games", value: "\(gameCount)")
                    StatRow(title: "Systems", value: "\(systemCount)")
                    StatRow(title: "Cores", value: "\(coreCount)")
                    StatRow(title: "Save States", value: "\(saveStateCount)")
                }

                Section("Game Stats") {
                    if gameCount > 0 {
                        NavigationLink("View by System", destination: GamesBySystemView())
                    } else {
                        Text("No games in database")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Database Stats")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                loadStats()
            }
        }
    }

    private func loadStats() {
        do {
            let realm = try Realm()
            gameCount = realm.objects(PVGame.self).count
            systemCount = realm.objects(PVSystem.self).count
            coreCount = realm.objects(PVCore.self).count
            saveStateCount = realm.objects(PVSaveState.self).count
        } catch {
            ELOG("Error loading database stats: \(error)")
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

struct GamesBySystemView: View {
    @ObservedResults(PVSystem.self) var systems

    var body: some View {
        List {
            ForEach(systems, id: \.self) { system in
                let gameCount = system.games.count

                HStack {
                    Text(system.name)
                    Spacer()
                    Text("\(gameCount) \(gameCount == 1 ? "game" : "games")")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Games by System")
    }
}

// MARK: - Database Browser View

struct DatabaseBrowserView: View {
    @ObservedResults(PVGame.self) var games

    var body: some View {
        List {
            ForEach(games, id: \.self) { game in
                VStack(alignment: .leading) {
                    Text(game.title)
                        .font(.headline)

                    Text(game.system?.name ?? "Unknown System")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(game.romPath)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Games (\(games.count))")
    }
}

// MARK: - Theme Preview View

struct ThemePreviewView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        SwiftUI.List {
            SwiftUI.Section("Text") {
                Text("Header")
                    .foregroundColor(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)

                Text("Title Text")
                    .font(.title)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                Text("Body Text")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }

            SwiftUI.Section("Colors") {
                ColorRow(name: "Header", color: themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
                ColorRow(name: "Background", color: themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                ColorRow(name: "Cell", color: themeManager.currentPalette.gameLibraryCellText.swiftUIColor)
                ColorRow(name: "Tint", color: themeManager.currentPalette.defaultTintColor.swiftUIColor)
                ColorRow(name: "Text", color: themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }

            SwiftUI.Section("UI Elements") {
                Toggle("Toggle", isOn: .constant(true))

                Picker("Picker", selection: .constant(1)) {
                    Text("Option 1").tag(1)
                    Text("Option 2").tag(2)
                }

                Button("Button") {
                    // Action
                }

                HStack {
                    Text("Slider")
                    Slider(value: .constant(0.5))
                }
            }
        }
        .navigationTitle("Theme Preview")
    }
}

struct ColorRow: View {
    let name: String
    let color: Color

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 30, height: 30)
        }
    }
}

// MARK: - Custom UI Components

struct GradientButtonStyle: ButtonStyle {
    let colors: [Color]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct ColorPalettePreview: View {
    let palette: any UXThemePalette

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ColorSwatch(color: palette.defaultTintColor.swiftUIColor, name: "Tint")
                ColorSwatch(color: palette.gameLibraryBackground.swiftUIColor, name: "Background")
                ColorSwatch(color: palette.gameLibraryText.swiftUIColor, name: "Text")
            }

            HStack(spacing: 8) {
                ColorSwatch(color: palette.gameLibraryHeaderText.swiftUIColor, name: "Header")
                ColorSwatch(color: palette.gameLibraryCellBackground?.swiftUIColor ?? .gray, name: "Cell")
                ColorSwatch(color: palette.gameLibraryCellText.swiftUIColor, name: "Cell Text")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 50, height: 50)
                .shadow(radius: 2)

            Text(name)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

// Add this view somewhere in your file
struct SaveStatesMockView: View {
    @State private var viewModel: ContinuesMagementViewModel?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading save states...")
            } else if let viewModel = viewModel {
                ContinuesMagementView(viewModel: viewModel)
                    .presentationBackground(.clear)
            } else {
                Text("Failed to load save states")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            loadViewModel()
        }
    }

    private func loadViewModel() {
        Task {
            // Create mock driver with sample data
            let mockDriver = MockSaveStateDriver(mockData: true)
            let saveStatesCount = await mockDriver.getAllSaveStates().count

            // Create view model with mock driver
            let newViewModel = ContinuesMagementViewModel(
                driver: mockDriver,
                gameTitle: mockDriver.gameTitle,
                systemTitle: mockDriver.systemTitle,
                numberOfSaves: saveStatesCount,
                gameUIImage: mockDriver.gameUIImage
            )

            // Update on main thread
            await MainActor.run {
                self.viewModel = newViewModel
                self.isLoading = false
            }
        }
    }
}

// Add this helper view to handle async loading of skins
struct DeltaSkinPreviewWrapper: View {
    @StateObject private var skinManager = DeltaSkinManager.shared
    @State private var skins: [DeltaSkinProtocol] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading skins...")
            } else if skins.isEmpty {
                Text("No skins available")
                    .padding()
            } else {
                DeltaSkinFullscreenPagerView(
                    skins: skins,
                    traits: DeltaSkinTraits(
                        device: .iphone,
                        displayType: .standard,
                        orientation: .portrait
                    )
                )
            }
        }
        .onAppear {
            loadSkins()
        }
    }

    private func loadSkins() {
        Task {
            do {
                // Get all available skins from the manager
                let availableSkins = try await skinManager.availableSkins()

                await MainActor.run {
                    self.skins = availableSkins
                    self.isLoading = false
                }
            } catch {
                print("Error loading skins: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

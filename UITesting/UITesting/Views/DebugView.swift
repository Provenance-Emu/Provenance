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

// MARK: - Retrowave Design System

// Retrowave color palette
extension Color {
    static let retroPink = Color(red: 0.98, green: 0.2, blue: 0.6)
    static let retroPurple = Color(red: 0.5, green: 0.0, blue: 0.8)
    static let retroBlue = Color(red: 0.0, green: 0.8, blue: 0.95)
    static let retroYellow = Color(red: 0.98, green: 0.84, blue: 0.2)
    static let retroOrange = Color(red: 0.98, green: 0.5, blue: 0.2)
    static let retroBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
    
    // Gradient helpers
    static let retroSunset = LinearGradient(
        gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let retroGrid = LinearGradient(
        gradient: Gradient(colors: [.retroBlue.opacity(0.7), .retroPurple.opacity(0.7)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let retroNeon = LinearGradient(
        gradient: Gradient(colors: [.retroPink, .retroPurple]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let retroCyber = LinearGradient(
        gradient: Gradient(colors: [.retroBlue, .retroPurple]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Gradient helpers
    static let retroGradient = LinearGradient(
        gradient: Gradient(colors: [.retroPurple, .retroPink]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let retroSunsetGradient = LinearGradient(
        gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
        startPoint: .top,
        endPoint: .bottom
    )
}

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
    
    // Add this state variable
    @State private var showAIEnhancements = false
    
    // Animation states
    @State private var scanlineOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.7
    
    var body: some View {
        NavigationStack {
            List {
                RetroSectionView(title: "DATABASE") {
                    Button("VIEW DATABASE STATS") {
                        showDatabaseStats = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple], glowColor: .retroBlue))
                    
                    Button("RESET DATABASE") {
                        showConfirmResetAlert = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroPink, .retroOrange], glowColor: .retroPink))
                    
                    NavigationLink("BROWSE GAMES") {
                        DatabaseBrowserView()
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroPurple, .retroBlue], glowColor: .retroPurple))
                }
                
                
                RetroSectionView(title: "IMPORT") {
                    Button("SHOW IMPORT QUEUE") {
                        showImportQueue = true
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroYellow, .retroOrange], glowColor: .retroYellow))
                    
                    Button("FORCE IMPORT SCAN") {
                        // Force a scan of the import directories
                        appState.gameImporter?.startProcessing()
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroOrange, .retroPink], glowColor: .retroOrange))
                    
                    Button("INSTALL TEST ROM") {
                        // Install the test ROM
                        Task {
                            do {
                                try await installTestROM()
                            } catch {
                                ELOG("Error installing test ROM: \(error)")
                            }
                        }
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroPink, .retroPurple], glowColor: .retroPink))
                }
                
                RetroSectionView(title: "UI TESTING") {
                    NavigationLink("THEME PREVIEW") {
                        ThemePreviewView()
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple], glowColor: .retroBlue))
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        Button("SAVE STATES") {
                            showSaveStatesMock = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple]))
                        
                        Button("GAME INFO") {
                            showGameMoreInfo = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroPurple, .retroPink]))
                        
                        Button("GAME INFO (REALM)") {
                            showGameMoreInfoRealm = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroPink, .retroOrange]))
                        
                        Button("ARTWORK SEARCH") {
                            showArtworkSearch = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroOrange, .retroYellow]))
                        
                        Button("FREE ROMS") {
                            showFreeROMs = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroYellow, .retroBlue]))
                        
                        Button("DELTA SKIN LIST") {
                            showDeltaSkinList = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple]))
                    }
                }
                
                RetroSectionView(title: "THEME TESTING") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SELECT THEME")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.retroBlue)
                            .shadow(color: .retroPink.opacity(0.8), radius: 2, x: 1, y: 1)
                        
                        Picker("Select Theme", selection: $selectedTheme) {
                            ForEach(ThemeName.allCases, id: \.self) { theme in
                                Text(theme.rawValue.uppercased()).tag(theme)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .onChange(of: selectedTheme) { newValue in
                            applyTheme(newValue)
                        }
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
                        .background(Color.retroBlack.opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    RetroPalettePreview(palette: themeManager.currentPalette)
                }
                
                RetroSectionView(title: "CONTROLLER SKINS") {
                    NavigationLink("BROWSE SYSTEM SKINS") {
                        SystemSkinBrowserView()
                    }
                    .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple], glowColor: .retroBlue))
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        Button("IMPORT SKIN") {
                            showDeltaSkinImport = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroPurple, .retroPink]))
                        
                        Button("SKIN PREVIEW") {
                            showDeltaSkinPreview = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroPink, .retroYellow]))
                        
                        Button("AI ENHANCE") {
                            showAIEnhancements = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroYellow, .retroBlue]))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("DEBUG CONSOLE")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
        .sheet(isPresented: $showAIEnhancements) {
            NavigationView {
                DeltaSkinAIEnhancementView()
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
        NavigationStack {
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
    let glowColor: Color
    let textShadow: Bool
    
    init(colors: [Color], glowColor: Color? = nil, textShadow: Bool = true) {
        self.colors = colors
        self.glowColor = glowColor ?? (colors.first ?? .retroPink)
        self.textShadow = textShadow
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced))
            .fontWeight(.bold)
            .tracking(1.2) // Letter spacing for that retro look
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    // Grid overlay
                    RetroGrid(lineSpacing: 8, lineColor: .white.opacity(0.15))
                }
            )
            .foregroundColor(.white)
            .ifApply(textShadow) { view in
                view.shadow(color: glowColor.opacity(0.8), radius: 0, x: 1.5, y: 1.5)
                    .shadow(color: glowColor.opacity(0.4), radius: 0, x: 3, y: 3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [colors.last ?? .white, colors.first ?? .white]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .cornerRadius(8)
            .shadow(color: glowColor.opacity(0.6), radius: 8, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Helper extension for conditional modifiers
extension View {
    @ViewBuilder
    func ifApply<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Retro grid component
struct RetroGrid: View {
    let lineSpacing: CGFloat
    let lineColor: Color
    
    var body: some View {
        ZStack {
            // Horizontal lines
            VStack(spacing: lineSpacing) {
                ForEach(0..<20) { _ in
                    Rectangle()
                        .fill(lineColor)
                        .frame(height: 1)
                }
            }
            
            // Vertical lines
            HStack(spacing: lineSpacing) {
                ForEach(0..<20) { _ in
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 1)
                }
            }
        }
    }
}

// Retrowave version of the palette preview
struct RetroPalettePreview: View {
    let palette: any UXThemePalette
    @State private var glowOpacity: Double = 0.7
    
    var body: some View {
        VStack(spacing: 16) {
            Text("COLOR PALETTE")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.retroPink)
                .shadow(color: .retroBlue.opacity(0.8), radius: 2, x: 1, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RetroColorSwatch(color: palette.defaultTintColor.swiftUIColor, name: "TINT")
                RetroColorSwatch(color: palette.gameLibraryBackground.swiftUIColor, name: "BG")
                RetroColorSwatch(color: palette.gameLibraryText.swiftUIColor, name: "TEXT")
                RetroColorSwatch(color: palette.gameLibraryHeaderText.swiftUIColor, name: "HEADER")
                RetroColorSwatch(color: palette.gameLibraryHeaderBackground.swiftUIColor, name: "HDR BG")
                RetroColorSwatch(color: palette.gameLibraryCellBackground?.swiftUIColor ?? .retroBlack, name: "CELL")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroBlack.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroBlue, .retroPink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .retroBlue.opacity(glowOpacity * 0.3), radius: 8, x: 0, y: 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

// Retrowave color swatch
struct RetroColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
            
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: .retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
        }
    }
}

// Retro section view
struct RetroSectionView<Content: View>: View {
    let title: String
    let content: Content
    @State private var glowOpacity: Double = 0.7
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text(title)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.retroPink)
                .shadow(color: .retroBlue.opacity(0.8), radius: 2, x: 2, y: 2)
                .padding(.bottom, 4)
            
            // Content
            content
        }
        .padding(20)
        .background(
            ZStack {
                // Base background
                Color.retroBlack.opacity(0.7)
                
                // Grid overlay
                RetroGrid(lineSpacing: 15, lineColor: .white.opacity(0.07))
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroBlue, .retroPink]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: .retroPink.opacity(glowOpacity * 0.3), radius: 10, x: 0, y: 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
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

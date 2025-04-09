//
//  RetroDebugView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
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

public struct RetroDebugView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState
    
    // Debug state
    @State private var showDatabaseStats = false
    @State private var showImportQueue = false
    @State private var showMockImportQueue = false
    @State private var showConfirmResetAlert = false
    
    // Mock importer for testing
    @StateObject private var importStatusDriverData = AppState.shared.gameImporter ?? GameImporter.shared
    
    @StateObject private var mockImportStatusDriverData = MockImportStatusDriverData()

    // Add these state variables at the top of the RetroDebugView struct
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
    
    public init() { }
    
    public var body: some View {
        NavigationStack {
            contentView()
                .retrowaveBackground()
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
        .sheet(isPresented: $showMockImportQueue) {
            ImportStatusView(
                updatesController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                gameImporter: mockImportStatusDriverData.gameImporter,
                delegate: mockImportStatusDriverData) {
                    showMockImportQueue = false
                }
        }
        .sheet(isPresented: $showImportQueue) {
            ImportStatusView(
                updatesController: appState.libraryUpdatesController!,
                gameImporter: appState.gameImporter!,
                delegate: nil) {
                    showImportQueue = false
                }
        }
        .sheet(isPresented: $showSaveStatesMock) {
            if #available(iOS 17.0, tvOS 17.0, watchOS 7.0, *) {
                SaveStatesMockView()
            }
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
            .modifier(PresentationBackgroundModifier())
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
    
    // These methods have been replaced by the RetrowaveBackgroundModifier
    
    @ViewBuilder
    func contentView() -> some View {
        // Content
        ScrollView {
            VStack(spacing: 24) {
                // DATABASE Section
                RetroSectionView(title: "DATABASE") {
                    VStack(spacing: 12) {
                        Button("VIEW DATABASE STATS") {
                            showDatabaseStats = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple], glowColor: .retroBlue))
                        .frame(maxWidth: .infinity)
                        
                        Button("RESET DATABASE") {
                            showConfirmResetAlert = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroPink, .retroOrange], glowColor: .retroPink))
                        .frame(maxWidth: .infinity)
                        
                        NavigationLink("BROWSE GAMES") {
                            DatabaseBrowserView()
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroPurple, .retroBlue], glowColor: .retroPurple))
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // IMPORT Section
                RetroSectionView(title: "IMPORT") {
                    VStack(spacing: 12) {
                        Button("SHOW IMPORT QUEUE") {
                            showImportQueue = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroYellow, .retroOrange], glowColor: .retroYellow))
                        .frame(maxWidth: .infinity)
                        
                        Button("SHOW MOCK IMPORT QUEUE") {
                            showMockImportQueue = true
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroYellow], glowColor: .retroBlue))
                        .frame(maxWidth: .infinity)
                        
                        Button("FORCE IMPORT SCAN") {
                            // Force a scan of the import directories
                            appState.gameImporter?.startProcessing()
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroOrange, .retroPink], glowColor: .retroOrange))
                        .frame(maxWidth: .infinity)
                        
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
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // UI TESTING Section
                RetroSectionView(title: "UI TESTING") {
                    VStack(spacing: 16) {
                        NavigationLink("THEME PREVIEW") {
                            ThemePreviewView()
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple], glowColor: .retroBlue))
                        .frame(maxWidth: .infinity)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            Button("SAVE STATES") {
                                showSaveStatesMock = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple]))
                            .frame(maxWidth: .infinity)
                            
                            Button("GAME INFO") {
                                showGameMoreInfo = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroPurple, .retroPink]))
                            .frame(maxWidth: .infinity)
                            
                            Button("GAME INFO (REALM)") {
                                showGameMoreInfoRealm = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroPink, .retroOrange]))
                            .frame(maxWidth: .infinity)
                            
                            Button("ARTWORK SEARCH") {
                                showArtworkSearch = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroOrange, .retroYellow]))
                            .frame(maxWidth: .infinity)
                            
                            Button("FREE ROMS") {
                                showFreeROMs = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroYellow, .retroBlue]))
                            .frame(maxWidth: .infinity)
                            
                            Button("DELTA SKIN LIST") {
                                showDeltaSkinList = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple]))
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                
                // THEME TESTING Section
                RetroSectionView(title: "THEME TESTING") {
                    VStack(spacing: 16) {
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
                        .frame(maxWidth: .infinity)
                        
                        RetroPalettePreview(palette: themeManager.currentPalette)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // CONTROLLER SKINS Section
                RetroSectionView(title: "CONTROLLER SKINS") {
                    VStack(spacing: 16) {
                        NavigationLink("BROWSE SYSTEM SKINS") {
                            SystemSkinBrowserView()
                        }
                        .buttonStyle(GradientButtonStyle(colors: [.retroBlue, .retroPurple], glowColor: .retroBlue))
                        .frame(maxWidth: .infinity)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            Button("IMPORT SKIN") {
                                showDeltaSkinImport = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroPurple, .retroPink]))
                            .frame(maxWidth: .infinity)
                            
                            Button("SKIN PREVIEW") {
                                showDeltaSkinPreview = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroPink, .retroYellow]))
                            .frame(maxWidth: .infinity)
                            
                            Button("AI ENHANCE") {
                                showAIEnhancements = true
                            }
                            .buttonStyle(GradientButtonStyle(colors: [.retroYellow, .retroBlue]))
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 100)
            .padding(.vertical, 16)
            .padding(.bottom, 40) // Extra padding at bottom for better scrolling
        }
    }
}

// MARK: - Database Stats View

// MARK: - Database Stats View

struct DatabaseStatsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Database stats
    @State private var gameCount = 0
    @State private var systemCount = 0
    @State private var coreCount = 0
    @State private var saveStateCount = 0
    
    // Animation states
    @State private var scanlineOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.7
    @State private var isLoading = true
    @State private var pulseOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
            
            // Grid overlay
            RetroGrid()
//                .opacity(0.3)
            
            // Content
            VStack(spacing: 20) {
                // Header
                Text("DATABASE STATS")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(RetroTheme.retroPink)
                    .padding(.top, 20)
                    .shadow(color: RetroTheme.retroPink.opacity(0.8), radius: 10, x: 0, y: 0)
                
                // Stats cards
                VStack(spacing: 16) {
                    // Main stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        RetroStatCard(title: "GAMES", value: "\(gameCount)", icon: "gamecontroller.fill", color: RetroTheme.retroPink)
                        RetroStatCard(title: "SYSTEMS", value: "\(systemCount)", icon: "cpu.fill", color: RetroTheme.retroPurple)
                        RetroStatCard(title: "CORES", value: "\(coreCount)", icon: "memorychip.fill", color: RetroTheme.retroBlue)
                        RetroStatCard(title: "SAVE STATES", value: "\(saveStateCount)", icon: "square.and.arrow.down.fill", color: RetroTheme.retroPink)
                    }
                    
                    // Navigation button
                    if gameCount > 0 {
                        NavigationLink(destination: GamesBySystemView()) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(RetroTheme.retroBlue)
                                Text("VIEW BY SYSTEM")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .background(Color.black.opacity(0.7))
                                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 8, x: 0, y: 0)
                            )
                        }
                    } else {
                        Text("NO GAMES IN DATABASE")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(RetroTheme.retroPink)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        RetroTheme.retroPink.opacity(0.8),
                                        lineWidth: 1
                                    )
                                    .background(Color.black.opacity(0.7))
                            )
                            .opacity(pulseOpacity)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever()) {
                                    pulseOpacity = 1.0
                                }
                            }
                    }
                    
                    // Done button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("DONE")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 8, x: 0, y: 0)
                            )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
            
            // Loading overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.7)
                    
                    VStack {
                        Text("SCANNING DATABASE")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(RetroTheme.retroPink)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: RetroTheme.retroPink))
                            .scaleEffect(1.5)
                            .padding()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Start animations
            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                scanlineOffset = 1000
            }
            
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
            
            // Load stats with a slight delay to show loading animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadStats()
                
                withAnimation {
                    isLoading = false
                }
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

struct RetroStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @State private var glowOpacity = 0.7
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
                .shadow(color: color.opacity(glowOpacity), radius: 8, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            color.opacity(0.8),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

struct GamesBySystemView: View {
    @ObservedResults(PVSystem.self) var systems
    
    var body: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
            
            // Grid overlay
            RetroGrid()
//                .opacity(0.3)
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(systems, id: \.self) { system in
                        let gameCount = system.games.count
                        
                        HStack {
                            // System icon or placeholder
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Text(String(system.name.prefix(1)))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(system.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(gameCount) \(gameCount == 1 ? "game" : "games")")
                                    .font(.system(size: 14))
                                    .foregroundColor(RetroTheme.retroPink)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(RetroTheme.retroBlue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            LinearGradient(
                                                gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("GAMES BY SYSTEM")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
// MARK: - Database Browser View

// MARK: - Database Browser View

struct DatabaseBrowserView: View {
    @ObservedResults(PVGame.self) var games
    
    // Animation states
    @State private var selectedGame: PVGame?
    @State private var showGameDetails = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var glowOpacity = 0.7
    @State private var scanlineOffset: CGFloat = 0
    
    var filteredGames: Results<PVGame> {
        if searchText.isEmpty {
            return games
        } else {
            return games.filter("title CONTAINS[c] %@", searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
            
            // Grid overlay
            RetroGrid()
//                .opacity(0.3)
            
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(isSearching ? RetroTheme.retroPink : .gray)
                    
                    TextField("SEARCH GAMES", text: $searchText)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onTapGesture {
                            isSearching = true
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(RetroTheme.retroBlue)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: isSearching ? 2 : 1
                                )
                        )
                )
                .padding(.horizontal)
                .padding(.top)
                
                // Game count
                Text("FOUND \(filteredGames.count) GAMES")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(RetroTheme.retroPink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Game list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredGames, id: \.self) { game in
                            RetroGameCard(game: game, isSelected: selectedGame == game)
                                .onTapGesture {
                                    withAnimation {
                                        if selectedGame == game {
                                            selectedGame = nil
                                        } else {
                                            selectedGame = game
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("GAME DATABASE")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            // Start animations
            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                scanlineOffset = 1000
            }
            
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

struct RetroGameCard: View {
    let game: PVGame
    let isSelected: Bool
    
    @State private var glowOpacity = 0.7
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                Text(game.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(RetroTheme.retroPurple)
                    
                    Text(game.system?.name ?? "Unknown System")
                        .font(.system(size: 14))
                        .foregroundColor(RetroTheme.retroPurple)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.5)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Expanded details
            if isSelected {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(RetroTheme.retroBlue)
                        
                        Text("ROM Path:")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(RetroTheme.retroBlue)
                    }
                    
                    Text(game.romPath)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let md5 = game.md5 {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(RetroTheme.retroPink)
                            
                            Text("MD5: \(md5)")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                    
                    if let lastPlayed = game.lastPlayed {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(RetroTheme.retroPink)
                            
                            Text("Last Played: \(formattedDate(lastPlayed))")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            // Action to play game
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("PLAY")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(RetroTheme.retroPink)
                                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 4, x: 0, y: 0)
                            )
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isSelected ? RetroTheme.retroPink : RetroTheme.retroPurple,
                                    RetroTheme.retroBlue
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: (isSelected ? RetroTheme.retroPink : RetroTheme.retroBlue).opacity(glowOpacity * (isSelected ? 1.0 : 0.5)),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: 0
                )
        )
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Content
            content
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            ZStack {
                // Base background
                Color.retroBlack.opacity(0.7)
                
                // Grid overlay
                RetroGrid(lineSpacing: 15, lineColor: Color.white.opacity(0.07))
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
        .frame(maxWidth: .infinity)
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
@available(iOS 17.0, tvOS 17.0, watchOS 7.0, *)
struct SaveStatesMockView: View {
    @State private var viewModel: ContinuesMagementViewModel?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading save states...")
            } else if let viewModel = viewModel {
                ContinuesManagementView(viewModel: viewModel)
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
            let saveStatesCount = mockDriver.getAllSaveStates().count
            
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
    @State private var skins: [any DeltaSkinProtocol] = []
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

// Helper modifier to handle presentationBackground availability
private struct PresentationBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(Color(uiColor: .systemBackground))
        } else {
            content
        }
    }
}

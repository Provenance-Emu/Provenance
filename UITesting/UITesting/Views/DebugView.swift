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

struct DebugView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState
    
    // Debug state
    @State private var showDatabaseStats = false
    @State private var showImportQueue = false
    @State private var showConfirmResetAlert = false
    
    // Mock importer for testing
    @StateObject private var mockImportStatusDriverData = MockImportStatusDriverData()
    
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
                        // Action to show save states UI
                    }
                    
                    Button("Show Game Info UI") {
                        // Action to show game info UI
                    }
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

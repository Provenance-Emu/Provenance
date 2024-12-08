//
//  UITestingApp.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes
import SwiftUI
import UIKit
import Perception

#if canImport(FreemiumKit)
import FreemiumKit
#endif

@main
struct UITestingApp: App {
    @State private var showingRealmSheet = false
    @State private var showingMockSheet = false
    @State private var showingSettings = false
    @State private var showImportStatus = false
    @State private var showGameMoreInfo = false
    @State private var showGameMoreInfoRealm = false

    @StateObject
    private var mockImportStatusDriverData = MockImportStatusDriverData()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.secondary.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    HStack {
                        Button("Show Realm Driver") {
                            showingRealmSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Show Mock Driver") {
                            showingMockSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    HStack {
                        Button("Show Settings") {
                            showingSettings = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Show Import Queue") {
                            showImportStatus = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    HStack {
                        Button("Show Game Info") {
                            showGameMoreInfo = true
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Show Game Info Realm") {
                            showGameMoreInfoRealm = true
                        }
                        .buttonStyle(.borderedProminent)

                    }
                }
            }
            .sheet(isPresented: $showingRealmSheet) {
                let testRealm = try! RealmSaveStateTestFactory.createInMemoryRealm()
                let mockDriver = try! RealmSaveStateDriver(realm: testRealm)
                
                /// Get the first game from realm for the view model
                let game = testRealm.objects(PVGame.self).first!
                
                /// Create view model with game data
                let viewModel = ContinuesMagementViewModel(
                    driver: mockDriver,
                    gameTitle: game.title,
                    systemTitle: "Game Boy",
                    numberOfSaves: game.saveStates.count
                )
                
                ContinuesMagementView(viewModel: viewModel)
                    .onAppear {
                        /// Load initial states through the publisher
                        mockDriver.loadSaveStates(forGameId: "1")
                    }
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingMockSheet) {
                /// Create mock driver with sample data
                let mockDriver = MockSaveStateDriver(mockData: true)
                /// Create view model with mock driver
                let viewModel = ContinuesMagementViewModel(
                    driver: mockDriver,
                    gameTitle: mockDriver.gameTitle,
                    systemTitle: mockDriver.systemTitle,
                    numberOfSaves: mockDriver.getAllSaveStates().count,
                    gameUIImage: mockDriver.gameUIImage
                )
                
                ContinuesMagementView(viewModel: viewModel)
                    .onAppear {
                    }
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingSettings) {
                let gameImporter = GameImporter.shared
                let pvgamelibraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter)
                let menuDelegate = MockPVMenuDelegate()
                
                PVSettingsView(
                    conflictsController: pvgamelibraryUpdatesController,
                    menuDelegate: menuDelegate) {
                        print("PVSettingsView Closed")
                    }
            }
            .sheet(isPresented: $showImportStatus) {
                ImportStatusView(
                    updatesController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                    gameImporter: mockImportStatusDriverData.gameImporter,
                    delegate: mockImportStatusDriverData) {
                        print("Import Status View Closed")
                    }
            }
            .sheet(isPresented: $showGameMoreInfo) {
                NavigationView {
                    GameMoreInfoView(viewModel: .mockViewModel())
                }
            }
            .sheet(isPresented: $showGameMoreInfoRealm) {
                if let driver = try? RealmGameLibraryDriver.previewDriver(),
                   let firstGameId = driver.firstGameId() {
                    GameMoreInfoView(
                        viewModel: GameMoreInfoViewModel(
                            driver: driver,
                            gameId: firstGameId
                        )
                    )
                    .previewDisplayName("Realm Driver")
                }
            }
            .onAppear {
#if canImport(FreemiumKit)
                FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
#endif
            }
        }
#if canImport(FreemiumKit)
        .environmentObject(FreemiumKit.shared)
#endif
    }
}

class MockPVMenuDelegate: PVMenuDelegate {
    func didTapImports() {
        
    }
    
    func didTapSettings() {
        
    }
    
    func didTapHome() {
        
    }
    
    func didTapAddGames() {
        
    }
    
    func didTapConsole(with consoleId: String) {
        
    }
    
    func didTapCollection(with collection: Int) {
        
    }
    
    func closeMenu() {
        
    }
}

struct MainView_Previews: PreviewProvider {
    @State static private var showSaveStatesMock = false
    @State static private var showingSettings = false
    @State static private var showImportQueue = false
    @State static private var mockImportStatusDriverData = MockImportStatusDriverData()
    
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Button("Show Realm Driver") { }
                    .buttonStyle(.borderedProminent)
                
                Button("Show Mock Driver") { }
                    .buttonStyle(.borderedProminent)
                
                Button("Show Settings") { }
                    .buttonStyle(.borderedProminent)
                
                Button("Show Import Queue") {
                    showImportQueue = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingSettings) {
            let gameImporter = MockGameImporter()
            let pvgamelibraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter)
            let menuDelegate = MockPVMenuDelegate()
            
            PVSettingsView(
                conflictsController: pvgamelibraryUpdatesController,
                menuDelegate: menuDelegate) {
                    
                }
        }
        .sheet(isPresented: .init(
            get: { mockImportStatusDriverData.isPresent },
            set: { mockImportStatusDriverData.isPresent = $0 }
        )) {
            ImportStatusView(
                updatesController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                gameImporter: mockImportStatusDriverData.gameImporter,
                delegate: mockImportStatusDriverData)
        }
        .onAppear {
#if canImport(FreemiumKit)
            FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
#endif
        }
    }
}

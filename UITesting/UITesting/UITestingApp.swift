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
import PVUIBase

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
    @State private var showArtworkSearch = false
    @State private var showFreeROMs = false
    @State private var showDeltaSkinList = false

    @StateObject
    private var mockImportStatusDriverData = MockImportStatusDriverData()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                List {
                    Button("Test DeltaSkins List") {
                        showDeltaSkinList = true
                    }
                    Button("Show Realm Driver") {
                        showingRealmSheet = true
                    }
                    Button("Show Mock Driver") {
                        showingMockSheet = true
                    }
                    Button("Show Settings") {
                        showingSettings = true
                    }
                    Button("Show Import Queue") {
                        showImportStatus = true
                    }
                }
                .navigationTitle("UI Testing")
            }
            .sheet(isPresented: $showingRealmSheet) {
                let testRealm = try! RealmSaveStateTestFactory.createInMemoryRealm()
                let mockDriver = RealmSaveStateDriver(realm: testRealm)

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
                NavigationView {
                    let gameImporter = GameImporter.shared
                    let pvgamelibraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter)
                    let menuDelegate = MockPVMenuDelegate()

                    PVSettingsView(
                        conflictsController: pvgamelibraryUpdatesController,
                        menuDelegate: menuDelegate
                    ) {
                        showingSettings = false
                    }
                    .navigationBarHidden(true)
                }
                .navigationViewStyle(.stack)
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
                }
            }
            .sheet(isPresented: $showDeltaSkinList) {
                NavigationView {
                    DeltaSkinListView(manager: DeltaSkinManager.shared)
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

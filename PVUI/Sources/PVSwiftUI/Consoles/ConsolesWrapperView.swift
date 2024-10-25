//
//  ConsolesWrapperView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/26/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVUIBase
import PVRealm
import PVThemes

@available(iOS 14, tvOS 14, *)
class ConsolesWrapperViewDelegate: ObservableObject {
    @Published var selectedTab = ""
}

@available(iOS 14, tvOS 14, *)
struct ConsolesWrapperView: SwiftUI.View {

    // MARK: - Properties

    @ObservedObject var delegate: ConsolesWrapperViewDelegate
    @ObservedObject var viewModel: PVRootViewModel
    weak var rootDelegate: PVRootDelegate!

    @State private var showEmptySystems: Bool
    @ObservedResults(PVSystem.self) private var consoles: Results<PVSystem>
    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: - Initializer

    init(
        consolesWrapperViewDelegate: ConsolesWrapperViewDelegate,
        viewModel: PVRootViewModel,
        rootDelegate: PVRootDelegate
    ) {
        self.delegate = consolesWrapperViewDelegate
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate

        #if targetEnvironment(simulator)
        _showEmptySystems = State(initialValue: true)
        #else
        _showEmptySystems = State(initialValue: false)
        #endif

        // Set the filter for consoles based on showEmptySystems
        let filter = showEmptySystems ? nil : NSPredicate(format: "games.@count > 0")
        _consoles = ObservedResults(PVSystem.self, filter: filter, sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: true))
    }

    // MARK: - Body

    var body: some SwiftUI.View {
        TabView(selection: $delegate.selectedTab) {
            if consoles.isEmpty {
                showNoConsolesView()
            } else {
                showConsoles()
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(consoles.count)
        .tint(themeManager.currentPalette.defaultTintColor?.swiftUIColor)
        .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
    }

    // MARK: - Helper Methods

    private func sortedConsoles() -> [PVSystem] {
        viewModel.sortConsolesAscending ? consoles.map { $0 } : consoles.reversed()
    }

    private func showNoConsolesView() -> some View {
        NoConsolesView(delegate: rootDelegate as! PVMenuDelegate)
            .tabItem {
                Label("No Consoles", systemImage: "xmark.circle")
            }
            .tag("noConsoles")
    }

    private func showConsoles() -> some View {
        ForEach(sortedConsoles(), id: \.self) { console in
            ConsoleGamesView(console: console, viewModel: viewModel, rootDelegate: rootDelegate)
                .tabItem {
                    Label(console.name, systemImage: console.iconName)
                }
                .tag(console.identifier)
        }
    }
}

#endif

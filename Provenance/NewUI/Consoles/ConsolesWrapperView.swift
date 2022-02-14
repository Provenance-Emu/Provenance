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

@available(iOS 14, tvOS 14, *)
class ConsolesWrapperViewDelegate: ObservableObject {
    @Published var selectedTab = ""
}

@available(iOS 14, tvOS 14, *)
struct ConsolesWrapperView: SwiftUI.View {
    
    @ObservedObject var delegate: ConsolesWrapperViewDelegate
    @ObservedObject var viewModel: PVRootViewModel
    var rootDelegate: PVRootDelegate!
    
    @ObservedResults(
        PVSystem.self,
        configuration: RealmConfiguration.realmConfig,
        filter: NSPredicate(format: "games.@count > 0"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: false)
    ) var consoles
    
    init(
        consolesWrapperViewDelegate: ConsolesWrapperViewDelegate,
        viewModel: PVRootViewModel,
        rootDelegate: PVRootDelegate
    ) {
        self.delegate = consolesWrapperViewDelegate
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate
    }
    
    var body: some SwiftUI.View {
        TabView(selection: $delegate.selectedTab) {
            if consoles.count > 0 {
                ForEach(
                    viewModel.sortConsolesAscending == true
                        ? consoles.reversed()
                        : consoles.map { $0 },
                    id: \.self
                ) { console in
                    ConsoleGamesView(console: console, viewModel: viewModel, rootDelegate: rootDelegate)
                        .tag(console.identifier)
                }
            } else {
                Text("No Consoles")
                    .tag("no consoles")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(consoles.count)
    }
}

#endif

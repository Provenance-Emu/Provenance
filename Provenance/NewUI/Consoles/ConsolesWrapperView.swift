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
    
    var gameLibrary: PVGameLibrary!
    var rootDelegate: PVRootDelegate!
    
//    @State var consoles: Results<PVSystem>
    @ObservedObject var consoles: BindableResults<PVSystem>
    
    init(
        consolesWrapperViewDelegate: ConsolesWrapperViewDelegate,
        gameLibrary: PVGameLibrary,
        rootDelegate: PVRootDelegate
    ) {
        self.delegate = consolesWrapperViewDelegate
        self.gameLibrary = gameLibrary
        self.rootDelegate = rootDelegate
        self.consoles = BindableResults(results: gameLibrary.activeSystems)
    }
    
    var body: some SwiftUI.View {
        TabView(selection: $delegate.selectedTab) {
            if consoles.results.count > 0 { // TODO: handle sorting
                ForEach(0..<consoles.results.count, id: \.self) { index in // TODO: do you need the counttype loop here? Check HomeView for alternate approach
                    ConsoleGamesView(gameLibrary: self.gameLibrary, console: consoles.results[index], rootDelegate: rootDelegate)
                        .tag(consoles.results[index].identifier)
                }
            } else {
                Text("No Consoles")
                    .tag("no consoles")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .id(consoles.results.count)
    }
}

#endif

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

@available(iOS 14.0.0, *)
struct ConsolesWrapperView: SwiftUI.View {
    
    var gameLibrary: PVGameLibrary!
    var gameLaunchDelegate: GameLaunchingViewController!
    
    @State var consoles: Results<PVSystem>?
    @State var selectedTab = ""
    
    init(gameLibrary: PVGameLibrary, delegate: GameLaunchingViewController, selectedTab: String?) {
        self.gameLibrary = gameLibrary
        self.gameLaunchDelegate = delegate
        self.selectedTab = selectedTab ?? ""
    }
    
    var body: some SwiftUI.View {
        TabView(selection: $selectedTab) {
            if let consoles = consoles, consoles.count > 0 { // TODO: handle sorting
                ForEach(0..<consoles.count, id: \.self) { index in
                    ConsoleGamesView(gameLibrary: self.gameLibrary, console: consoles[index], delegate: gameLaunchDelegate)
                        .tag(consoles[index].identifier)
                }
            } else {
                Text("No Consoles")
                    .tag("no consoles")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .id(consoles?.count ?? -1)
        .onAppear {
            consoles = try? Realm().objects(PVSystem.self).filter("games.@count > 0").sorted(byKeyPath: "name") // TODO: the async nature of this call is causing some bugs
        }
    }
}

#endif

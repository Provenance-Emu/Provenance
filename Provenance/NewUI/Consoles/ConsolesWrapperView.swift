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
    
    @State var consoles: Results<PVSystem>
    
    init(
        consolesWrapperViewDelegate: ConsolesWrapperViewDelegate,
        gameLibrary: PVGameLibrary,
        rootDelegate: PVRootDelegate,
        consoles: Results<PVSystem>
    ) {
        self.delegate = consolesWrapperViewDelegate
        self.gameLibrary = gameLibrary
        self.consoles = consoles
        self.rootDelegate = rootDelegate
    }
    
    var body: some SwiftUI.View {
        TabView(selection: $delegate.selectedTab) {
            if consoles.count > 0 { // TODO: handle sorting
                ForEach(0..<consoles.count, id: \.self) { index in
                    ConsoleGamesView(gameLibrary: self.gameLibrary, console: consoles[index], rootDelegate: rootDelegate)
                        .tag(consoles[index].identifier)
                }
            } else {
                Text("No Consoles")
                    .tag("no consoles")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .id(consoles.count)
    }
}

#endif

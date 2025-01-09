//
//  MessageInBottleApp.swift
//  Message in a Bottle
//
//  Created by Drew McCormack on 09/02/2023.
//

import SwiftUI

@main
@MainActor
struct MessageInBottleApp: App {
    @StateObject var store: Store = .init()
    var body: some Scene {
        WindowGroup {
            BottleView()
                .environmentObject(store)
        }
    }
}

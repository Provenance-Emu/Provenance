//
//  SystemPickerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/31/24.
//

import Foundation
import SwiftUI
import PVLibrary
import RealmSwift
import PVUIBase
import PVRealm
import PVLogging
import PVUIBase

public struct SystemPickerView: View {
    let game: PVGame
    let availableSystems: [PVSystem]
    @Binding var isPresented: Bool

    /// Initialize with game and isPresented binding
    /// - Parameters:
    ///   - game: The game to move
    ///   - availableSystems: Available systems to move the game to
    ///   - isPresented: Binding to control sheet presentation
    public init(game: PVGame, availableSystems: [PVSystem], isPresented: Binding<Bool>) {
        self.game = game
        self.availableSystems = availableSystems
        _isPresented = isPresented
    }

    /// Backward compatibility initializer
    public init(game: PVGame, isPresented: Binding<Bool>) {
        self.game = game
        self.availableSystems = PVEmulatorConfiguration.systems.filter {
            $0.identifier != game.systemIdentifier &&
            !(AppState.shared.isAppStore && $0.appStoreDisabled)
        }
        _isPresented = isPresented
    }

    public var body: some View {
        if !availableSystems.isEmpty {
            NavigationStack {
                List {
                    ForEach(availableSystems) { system in
                        Button {
                            moveGame(to: system)
                            isPresented = false
                        } label: {
                            SystemRowView(system: system)
                        }
                    }
                }
                .navigationTitle("Select System")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
            }.onAppear {
                DLOG("Loading systems for game: \(game.title)")
                let systemsList = PVEmulatorConfiguration.systems.map{ $0.identifier }.joined(separator: ", ")
                ILOG("Systemslist: \(systemsList)")
            }
        }
    }

    private func moveGame(to newSystem: PVSystem) {
        DLOG("Moving game '\(game.title)' to system: \(newSystem.name)")
        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            try GameSystemMover.move(game, to: newSystem, in: realm)
            DLOG("Moved game '\(game.title)' to \(newSystem.name)")
        } catch {
            ELOG("Failed to move game to new system: \(error.localizedDescription)")
        }
    }
}

public struct SystemRowView: View {
    let system: PVSystem

    public init(system: PVSystem) {
        self.system = system
    }

    public var body: some View {
        HStack {
            Text(system.name)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }
}

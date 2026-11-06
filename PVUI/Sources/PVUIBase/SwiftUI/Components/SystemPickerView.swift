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
    /// Called once a move has been attempted, with the chosen system and its outcome, before
    /// the picker is dismissed. Screens that keep their own snapshot of the library use it to
    /// reload both systems and to tell the user when the move failed; without it a failure
    /// is only logged and the picker closes as if nothing had gone wrong.
    let onMoveCompleted: ((PVSystem, Result<Void, Error>) -> Void)?

    /// Initialize with game and isPresented binding
    /// - Parameters:
    ///   - game: The game to move
    ///   - availableSystems: Available systems to move the game to
    ///   - isPresented: Binding to control sheet presentation
    ///   - onMoveCompleted: Optional hook told how the move went
    public init(game: PVGame, availableSystems: [PVSystem], isPresented: Binding<Bool>, onMoveCompleted: ((PVSystem, Result<Void, Error>) -> Void)? = nil) {
        self.game = game
        self.availableSystems = availableSystems
        _isPresented = isPresented
        self.onMoveCompleted = onMoveCompleted
    }

    /// Backward compatibility initializer
    public init(game: PVGame, isPresented: Binding<Bool>, onMoveCompleted: ((PVSystem, Result<Void, Error>) -> Void)? = nil) {
        self.game = game
        self.availableSystems = PVEmulatorConfiguration.systems.filter {
            $0.identifier != game.systemIdentifier &&
            !(AppState.shared.isAppStore && $0.appStoreDisabled)
        }
        _isPresented = isPresented
        self.onMoveCompleted = onMoveCompleted
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
        let result: Result<Void, Error>
        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            try GameSystemMover.move(game, to: newSystem, in: realm)
            DLOG("Moved game '\(game.title)' to \(newSystem.name)")
            result = .success(())
        } catch {
            ELOG("Failed to move game to new system: \(error.localizedDescription)")
            result = .failure(error)
        }
        onMoveCompleted?(newSystem, result)
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

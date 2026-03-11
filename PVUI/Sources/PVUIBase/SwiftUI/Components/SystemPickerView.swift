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
            guard let sourceURL = PVEmulatorConfiguration.path(forGame: game) else {
                ELOG("Cannot move game with no path")
                return
            }
            let destinationURL = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: newSystem.identifier)
                .appendingPathComponent(sourceURL.lastPathComponent)

            // Save old values for cache cleanup
            let oldRomPath = game.romPath
            let oldSystemIdentifier = game.systemIdentifier
            let oldFileURL = game.file?.url
            let oldRelatedFiles = Array(game.relatedFiles.compactMap { $0.url })

            // Move the actual file first
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            DLOG("Successfully moved game file to new system directory <\(destinationURL.path())>")

            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            var updatedGame: PVGame?
            try realm.write {
                /// Thaw the PVGame for editing
                let thawedGame = game.thaw()
                thawedGame?.system = newSystem
                DLOG("Updated game system to: \(newSystem.name)")
                thawedGame?.systemIdentifier = newSystem.identifier
                DLOG("Updated game systemIdentifier to: \(newSystem.identifier)")

                // Update file path to new system directory
                let fileName = sourceURL.lastPathComponent
                let partialPath: String = (newSystem.identifier as NSString).appendingPathComponent(fileName)
                thawedGame?.romPath = partialPath
                DLOG("Updated game romPath to: \(partialPath)")

                // Update PVFile to point to the new location
                // Create a new PVFile with the destination URL, which will calculate the correct partialPath
                let newFile = PVFile(withURL: destinationURL)
                thawedGame?.file = newFile
                DLOG("Updated PVFile to point to new location: \(newFile.partialPath)")

                updatedGame = thawedGame
            }

            // Update cache: remove old entries and add new ones
            if let game = updatedGame {
                RomDatabase.removeGameFromCache(oldRomPath: oldRomPath, oldSystemIdentifier: oldSystemIdentifier, oldFileURL: oldFileURL, oldRelatedFiles: oldRelatedFiles)
                RomDatabase.addGameToCache(game)
                DLOG("Updated games cache after moving game to new system")
            }

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

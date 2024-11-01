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

struct SystemPickerView: View {
    let game: PVGame
    @Binding var isPresented: Bool
//    @ObservedResults(PVSystem.self) private var systems: Results<PVSystem>
//    
//    init(game: PVGame, isPresented: Binding<Bool>) {
//        self.game = game
//        _isPresented = isPresented
//        
//        let filter =  NSPredicate(format: "identifier != %@", argumentArray: [game.systemIdentifier])
//        _systems = ObservedResults(PVSystem.self, filter: filter, sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: true))
//    }

    var body: some View {
        NavigationView {
            List {
                ForEach(PVEmulatorConfiguration.systems) { system in
                    Button {
                        moveGame(to: system)
                        isPresented = false
                    } label: {
                        HStack {
                            Text(system.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Select System")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }.onAppear {
            DLOG("Loading systems for game: \(game.title)")
            let systemsList = PVEmulatorConfiguration.systems.map{ $0.identifier }.joined(separator: ", ")
            ILOG("Systemslist: \(systemsList)")
        }
    }

    private func moveGame(to newSystem: PVSystem) {
        DLOG("Moving game '\(game.title)' to system: \(newSystem.name)")

        do {
            let sourceURL = PVEmulatorConfiguration.path(forGame: game)
            let destinationURL = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: newSystem.identifier)
                .appendingPathComponent(sourceURL.lastPathComponent)

            let realm = try Realm()
            try realm.write {
                let thawedGame = game.thaw()
                thawedGame?.system = newSystem
                DLOG("Updated game system to: \(newSystem.name)")
                thawedGame?.systemIdentifier = newSystem.identifier
                DLOG("Updated game system to: \(newSystem.identifier)")
                
                // Update file path to new system directory
                let fileName = (thawedGame?.romPath as NSString?)?.lastPathComponent ?? ""
                let partialPath: String = (newSystem.identifier as NSString).appendingPathComponent(fileName)
                thawedGame?.romPath = partialPath
                DLOG("Updated game file path to: \(partialPath)")
//                thawedGame?.romPath = "\(newSystem.identifier)/\(fileName)"
            }

            // Move the actual file

            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            DLOG("Successfully moved game file to new system directory <\(destinationURL.path())>")

        } catch {
            ELOG("Failed to move game to new system: \(error.localizedDescription)")
        }
    }
}

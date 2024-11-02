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

    private var availableSystems: [PVSystem] {
        PVEmulatorConfiguration.systems.filter { $0.identifier != game.systemIdentifier }
    }

    var body: some View {
        NavigationView {
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
                /// Thaw the PVGame for editing
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

struct SystemRowView: View {
    let system: PVSystem

    var body: some View {
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

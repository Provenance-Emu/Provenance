//
//  SystemSelectionView.swift
//  PVUI
//
//  Created by David Proskin on 11/7/24.
//

import SwiftUI
import PVLibrary
import Perception
import PVSystems

struct SystemSelectionView: View {
    @ObservedObject var item: ImportQueueItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        WithPerceptionTracking {
        List {
            ForEach(item.systems.sorted(), id: \.self) { system in
                Button(action: {
                    // Set the chosen system and update the status
                    item.userChosenSystem = system
                    item.status = .queued
                    // Dismiss the view
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(system.fullName)
                        .font(.headline)
                        .padding()
                }
            }
        }
        .navigationTitle("Select System")
        }
    }
}

#if DEBUG
import PVPrimitives
#Preview {
    
    
    let item: ImportQueueItem = {
        let systems: [SystemIdentifier] = [
            .AtariJaguar, .AtariJaguarCD
        ]

        let item = ImportQueueItem(url: .init(fileURLWithPath: "Test.bin"),
                        fileType: .game)
        item.systems = systems
        return item
    }()
    
    List {
        SystemSelectionView(item: item)
    }
}
#endif

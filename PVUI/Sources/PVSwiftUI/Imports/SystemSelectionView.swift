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
import PVThemes

struct SystemSelectionView: View {
    @ObservedObject var item: ImportQueueItem
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var themeManager = ThemeManager.shared

    // Replace delegate with callback
    var onSystemSelected: ((SystemIdentifier, ImportQueueItem) -> Void)?

    var body: some View {
        List {
            ForEach(item.systems.sorted(), id: \.self) { system in
                Button(action: {
                    // Set the chosen system
                    item.userChosenSystem = system

                    // Call the callback
                    onSystemSelected?(system, item)

                    // Dismiss the view
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(system.fullName)
                        .foregroundColor(themeManager.currentPalette.menuText.swiftUIColor)
                }
            }
        }
        .navigationTitle("Select System")
        .background(themeManager.currentPalette.menuBackground.swiftUIColor)
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

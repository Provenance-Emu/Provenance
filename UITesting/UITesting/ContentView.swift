//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVLookup
import PVLookupTypes
import PVSystems

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                // Continues Management Demo
                NavigationLink("Continues Management") {
                    let mockDriver = MockSaveStateDriver(mockData: true)
                    let viewModel = ContinuesMagementViewModel(
                        driver: mockDriver,
                        gameTitle: mockDriver.gameTitle,
                        systemTitle: mockDriver.systemTitle,
                        numberOfSaves: mockDriver.getAllSaveStates().count,
                        gameUIImage: mockDriver.gameUIImage
                    )
                    ContinuesMagementView(viewModel: viewModel)
                        .onAppear {
                            Task {
                                mockDriver.saveStatesSubject.send(await mockDriver.getAllSaveStates())
                            }
                        }
                }

                // Artwork Search Demo
                NavigationLink("Artwork Search") {
                    ArtworkSearchView { selection in
                        print("Selected artwork: \(selection.metadata.url)")
                    }
                }
            }
            .navigationTitle("UI Tests")
        }
    }
}

#Preview {
    ContentView()
}

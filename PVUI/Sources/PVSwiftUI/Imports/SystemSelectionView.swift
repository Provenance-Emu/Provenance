//
//  SystemSelectionView.swift
//  PVUI
//
//  Created by David Proskin on 11/7/24.
//

import SwiftUI

struct SystemSelectionView: View {
    @ObservedObject var item: ImportQueueItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            ForEach(item.systems, id: \.self) { system in
                Button(action: {
                    // Set the chosen system and update the status
//                    item.userChosenSystem = system
//                    item.status = .queued
                    // Dismiss the view
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(system.name)
                        .font(.headline)
                        .padding()
                }
            }
        }
        .navigationTitle("Select System")
    }
}

#Preview {
    
}

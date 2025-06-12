//
//  PagedSkinTestView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/25.
//

import SwiftUI

// Add this new view:
struct PagedSkinTestView: View {
    let skins: [any DeltaSkinProtocol]
    let initialIndex: Int

    @State private var selectedIndex: Int

    init(skins: [any DeltaSkinProtocol], initialIndex: Int) {
        self.skins = skins
        self.initialIndex = initialIndex
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(skins.enumerated()), id: \.element.identifier) { index, skin in
                DeltaSkinTestView(skin: skin)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(selectedIndex + 1) of \(skins.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

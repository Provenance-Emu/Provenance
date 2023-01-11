//
//  HomeItemView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/1/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

import SwiftUI

@available(iOS 15, tvOS 15, *)
struct HomeItemView: SwiftUI.View {

    var imageName: String
    var rowTitle: String

    var body: some SwiftUI.View {
        HStack(spacing: 0) {
            Image(imageName).resizable().scaledToFit().cornerRadius(4).padding(8)
            Text(rowTitle).foregroundColor(Color.white)
            Spacer()
        }
        .frame(height: 40.0)
        .background(Theme.currentTheme.gameLibraryBackground.swiftUIColor)
    }
}

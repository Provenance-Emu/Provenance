//
//  HomeDividerView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/1/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

import SwiftUI

@available(iOS 15, tvOS 15, *)
struct HomeDividerView: SwiftUI.View {
    var body: some SwiftUI.View {
        Divider()
            .frame(height: 1)
            .background(Theme.currentTheme.gameLibraryText.swiftUIColor)
            .opacity(0.1)
            .padding(.horizontal, 10)
    }
}

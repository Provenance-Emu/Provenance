//
//  HomeDividerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVUIBase

@available(iOS 14, tvOS 14, *)
struct HomeDividerView: SwiftUI.View {
    var body: some SwiftUI.View {
        Rectangle()
            .fill(Color.retroCyan.opacity(0.15))
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
}

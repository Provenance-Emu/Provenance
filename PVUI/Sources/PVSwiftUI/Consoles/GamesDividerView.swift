//
//  GamesDividerView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import PVUIBase

@available(iOS 14, tvOS 14, *)
struct GamesDividerView: SwiftUI.View {
    var body: some SwiftUI.View {
        Rectangle()
            .fill(Color.retroCyan.opacity(0.15))
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
}
#endif

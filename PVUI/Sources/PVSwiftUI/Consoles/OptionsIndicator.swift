//
//  OptionsIndicator.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary

@available(iOS 14, tvOS 14, *)
struct OptionsIndicator<Content: SwiftUI.View>: SwiftUI.View {

    var pointDown: Bool = true
    var chevronSize: CGFloat = 12.0

    var action: () -> Void

    @ViewBuilder var label: () -> Content

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 3) {
                label()
                Image(systemName: pointDown == true ? "chevron.down" : "chevron.up")
                    .foregroundColor(.gray)
                    .font(.system(size: chevronSize, weight: .ultraLight))
            }
        }
    }
}

#endif

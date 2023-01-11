//
//  HomeSection.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/1/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

import SwiftUI

@available(iOS 15, tvOS 15, *)
struct HomeSection<Content: SwiftUI.View>: SwiftUI.View {

    let title: String

    @ViewBuilder var content: () -> Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    content()
                }
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 5)
        }
    }
}

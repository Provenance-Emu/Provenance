//
//  HomeSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVThemes

@available(iOS 14, tvOS 14, *)
struct HomeSection<Content: SwiftUI.View>: SwiftUI.View {

    let title: String

    @ViewBuilder var content: () -> Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
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

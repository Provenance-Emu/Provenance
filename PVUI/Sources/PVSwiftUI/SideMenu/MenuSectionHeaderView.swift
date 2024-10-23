//
//  MenuSectionHeaderView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/4/24.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
@_exported import PVUIBase

#if canImport(Introspect)
import Introspect
#endif
@available(iOS 14, tvOS 14, *)
internal struct MenuSectionHeaderView: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var sectionTitle: String
    var sortable: Bool
    var sortAscending: Bool = false
    var action: () -> Void

    var body: some SwiftUI.View {
        VStack(spacing: 0) {
            /// Divider
            Divider().frame(height: 2)
                .background(themeManager.currentTheme.menuDivider.swiftUIColor)
            /// Spacer
            Spacer()
            
            HStack(alignment: .bottom) {
                Text(sectionTitle)
                    .foregroundColor(themeManager.currentTheme.gameLibraryText.swiftUIColor)
                    .font(.system(size: 13))
                Spacer()
                if sortable {
                    OptionsIndicator(pointDown: sortAscending, action: action) {
                        Text("Sort")
                            .foregroundColor(themeManager.currentTheme.menuIconTint.swiftUIColor)
                            .font(.system(.caption))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .background(themeManager.currentTheme.menuHeaderBackground.swiftUIColor)
        }
        .frame(height: 40.0)
        .background(themeManager.currentTheme.menuHeaderBackground.swiftUIColor)
    }
}
#endif

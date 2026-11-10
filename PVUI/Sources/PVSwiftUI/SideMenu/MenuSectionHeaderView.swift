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

@available(iOS 14, tvOS 14, *)
internal struct MenuSectionHeaderView: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var sectionTitle: String
    var sortable: Bool
    var sortAscending: Bool = false
    var action: () -> Void

    var body: some SwiftUI.View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .bottom) {
                Text(sectionTitle)
                    .foregroundColor(themeManager.currentPalette.menuSectionHeaderText.swiftUIColor)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                Spacer()
                if sortable {
                    OptionsIndicator(pointDown: sortAscending, action: action) {
                        Text("Sort")
                            .foregroundColor(themeManager.currentPalette.menuHeaderIconTint.swiftUIColor)
                            .font(.system(.caption))
                    }
                }
            }
            .padding(.horizontal, LibraryLayout.chromeHorizontalInset)
            .padding(.bottom, 4)
        }
        .frame(height: 40.0)
        .foregroundStyle(themeManager.currentPalette.menuSectionHeaderText.swiftUIColor)
        .tint(themeManager.currentPalette.menuSectionHeaderIconTint.swiftUIColor)
    }
}
#endif

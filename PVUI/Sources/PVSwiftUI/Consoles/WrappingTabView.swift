//
//  WrappingTabView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/22/24.
//

import SwiftUI

struct WrappingTabView<Content: View, EmptyContent: View>: View {
    let tabCount: Int
    @Binding var selection: Int
    let content: Content
    let emptyContent: EmptyContent
    
    init(tabCount: Int,
         selection: Binding<Int>,
         @ViewBuilder content: () -> Content,
         @ViewBuilder emptyContent: () -> EmptyContent) {
        self.tabCount = tabCount
        self._selection = selection
        self.content = content()
        self.emptyContent = emptyContent()
    }
    
    var body: some View {
        if tabCount == 0 {
            emptyContent
        } else {
            TabView(selection: $selection) {
                content
            }
            .onChange(of: selection) { newValue in
                if newValue < 0 {
                    selection = tabCount - 1
                } else if newValue >= tabCount {
                    selection = 0
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        }
    }
}

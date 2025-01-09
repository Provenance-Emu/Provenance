//
//  StatusBarProtectionWrapper.swift
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

internal struct StatusBarProtectionWrapper<Content: SwiftUI.View>: SwiftUI.View {
    // Scroll content inside of PVRootViewController's containerView will appear up in the status bar for some reason
    // Even though certain views will never have multiple pages/tabs, wrap them in a paged TabView to prevent this behavior
    // Note that this may potentially have side effects if your content contains certain views, but is working so far
    @ViewBuilder var content: () -> Content
    var body: some SwiftUI.View {
        TabView {
            content()
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .ignoresSafeArea(.all, edges: .bottom)
    }
}
#endif

//
//  HomeContinueSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes

@available(iOS 15, tvOS 15, *)
struct HomeContinueSection: SwiftUI.View {

    var continueStates: Results<PVSaveState>
    weak var rootDelegate: PVRootDelegate?
    let height: CGFloat = 260

    var body: some SwiftUI.View {

        TabView {
            if continueStates.count > 0 {
                ForEach(continueStates, id: \.self) { state in
                    HomeContinueItemView(continueState: state, height: height) {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(state.game, sender: self, core: state.core, saveState: state)}
                    }
                }
            } else {
                Text("No Continues")
                    .tag("no continues")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(continueStates.count)
        .frame(height: height)
    }
}

#endif

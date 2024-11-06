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
    @ObservedObject private var themeManager = ThemeManager.shared

    @ObservedResults(
        PVSaveState.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var allSaveStates

    weak var rootDelegate: PVRootDelegate?
    let height: CGFloat = 260
    var consoleIdentifier: String?

    var filteredSaveStates: [PVSaveState] {
        let validSaveStates = allSaveStates.filter { !$0.isInvalidated }

        if let consoleIdentifier = consoleIdentifier {
            return validSaveStates.filter {
                !$0.game.isInvalidated &&
                $0.game.systemIdentifier == consoleIdentifier
            }
        } else {
            return validSaveStates.filter { !$0.game.isInvalidated }
        }
    }

    var body: some SwiftUI.View {
        TabView {
            if filteredSaveStates.count > 0 {
                ForEach(filteredSaveStates, id: \.self) { state in
                    HomeContinueItemView(continueState: state, height: height, hideSystemLabel: consoleIdentifier != nil) {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(state.game, sender: self, core: state.core, saveState: state)
                        }
                    }
                }
            } else {
                Text("No Continues")
                    .tag("no continues")
                    .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(filteredSaveStates.count)
        .frame(height: height)
    }
}

#endif

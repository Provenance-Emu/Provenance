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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @ObservedResults(
        PVSaveState.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var allSaveStates

    weak var rootDelegate: PVRootDelegate?
    let defaultHeight: CGFloat = 260
    var consoleIdentifier: String?

    var isLandscapePhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone &&
               verticalSizeClass == .compact
        #else
        return false
        #endif
    }

    var adjustedHeight: CGFloat {
        isLandscapePhone ? defaultHeight / 2 : defaultHeight
    }

    var columns: Int {
        isLandscapePhone ? 2 : 1
    }

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

    var gridColumns: [GridItem] {
        if isLandscapePhone {
            [GridItem(.flexible()), GridItem(.flexible())]
        } else {
            [GridItem(.flexible())]
        }
    }

    var body: some SwiftUI.View {
        TabView {
            if filteredSaveStates.count > 0 {
                ForEach(0..<pageCount, id: \.self) { pageIndex in
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        if isLandscapePhone {
                            let startIndex = pageIndex * 2
                            let endIndex = min(startIndex + 2, filteredSaveStates.count)
                            
                            if startIndex < filteredSaveStates.count {
                                ForEach(startIndex..<endIndex, id: \.self) { index in
                                    if index < filteredSaveStates.count {  // Additional safety check
                                        HomeContinueItemView(
                                            continueState: filteredSaveStates[index],
                                            height: adjustedHeight,
                                            hideSystemLabel: consoleIdentifier != nil
                                        ) {
                                            Task.detached { @MainActor in
                                                await rootDelegate?.root_load(
                                                    filteredSaveStates[index].game,
                                                    sender: self,
                                                    core: filteredSaveStates[index].core,
                                                    saveState: filteredSaveStates[index]
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            if pageIndex < filteredSaveStates.count {  // Safety check for portrait mode
                                HomeContinueItemView(
                                    continueState: filteredSaveStates[pageIndex],
                                    height: adjustedHeight,
                                    hideSystemLabel: consoleIdentifier != nil
                                ) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(
                                            filteredSaveStates[pageIndex].game,
                                            sender: self,
                                            core: filteredSaveStates[pageIndex].core,
                                            saveState: filteredSaveStates[pageIndex]
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
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
        .frame(height: adjustedHeight)
    }

    // Computed property for page count
    private var pageCount: Int {
        if isLandscapePhone {
            return (filteredSaveStates.count + 1) / 2
        } else {
            return filteredSaveStates.count
        }
    }
}

#endif

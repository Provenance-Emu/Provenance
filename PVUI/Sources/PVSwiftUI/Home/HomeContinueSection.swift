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
import Combine

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

    @FocusState private var focusedSaveState: String?
    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

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

    // Add properties for navigation
    @State private var continuousNavigationTask: Task<Void, Never>?
    @State private var delayTask: Task<Void, Never>?
    @State private var gamepadCancellable: AnyCancellable?

    var body: some SwiftUI.View {
        TabView {
            if filteredSaveStates.count > 0 {
                ForEach(0..<pageCount, id: \.self) { pageIndex in
                    SaveStatesGridView(
                        pageIndex: pageIndex,
                        filteredSaveStates: filteredSaveStates,
                        isLandscapePhone: isLandscapePhone,
                        gridColumns: gridColumns,
                        adjustedHeight: adjustedHeight,
                        hideSystemLabel: consoleIdentifier != nil,
                        rootDelegate: rootDelegate,
                        focusedSaveState: $focusedSaveState,
                        parentFocusedSection: $parentFocusedSection,
                        parentFocusedItem: $parentFocusedItem
                    )
                    .padding(.horizontal)
                }
            } else {
                EmptyContinuesView()
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

    private func setupGamepadHandling() {
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] event in
                switch event {
                case .buttonPress(let isPressed):
                    if isPressed {
                        handleButtonPress()
                    }
                case .horizontalNavigation(let value, let isPressed):
                    if isPressed {
                        handleHorizontalNavigation(value)
                    }
                default:
                    break
                }
            }
    }

    private func handleButtonPress() {
        if let focused = focusedSaveState,
           let saveState = filteredSaveStates.first(where: { $0.id == focused }) {
            Task.detached { @MainActor in
                await self.rootDelegate?.root_load(
                    saveState.game,
                    sender: self,
                    core: saveState.core,
                    saveState: saveState
                )
            }
        }
    }

    private func handleHorizontalNavigation(_ value: Float) {
        let items = filteredSaveStates.map { $0.id }

        if let currentItem = focusedSaveState,
           let currentIndex = items.firstIndex(of: currentItem) {
            let newIndex = value < 0 ?
                (currentIndex == 0 ? items.count - 1 : currentIndex - 1) :
                (currentIndex == items.count - 1 ? 0 : currentIndex + 1)
            focusedSaveState = items[newIndex]
        } else {
            focusedSaveState = items.first
        }
    }
}

// Create a new struct for the grid view
private struct SaveStatesGridView: View {
    let pageIndex: Int
    let filteredSaveStates: [PVSaveState]
    let isLandscapePhone: Bool
    let gridColumns: [GridItem]
    let adjustedHeight: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @FocusState.Binding var focusedSaveState: String?
    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            if isLandscapePhone {
                LandscapeGridContent(
                    pageIndex: pageIndex,
                    filteredSaveStates: filteredSaveStates,
                    adjustedHeight: adjustedHeight,
                    hideSystemLabel: hideSystemLabel,
                    rootDelegate: rootDelegate,
                    focusedSaveState: $focusedSaveState,
                    parentFocusedSection: $parentFocusedSection,
                    parentFocusedItem: $parentFocusedItem
                )
            } else {
                PortraitGridContent(
                    pageIndex: pageIndex,
                    filteredSaveStates: filteredSaveStates,
                    adjustedHeight: adjustedHeight,
                    hideSystemLabel: hideSystemLabel,
                    rootDelegate: rootDelegate,
                    focusedSaveState: $focusedSaveState,
                    parentFocusedSection: $parentFocusedSection,
                    parentFocusedItem: $parentFocusedItem
                )
            }
        }
    }
}

// Create separate views for landscape and portrait content
private struct LandscapeGridContent: View {
    let pageIndex: Int
    let filteredSaveStates: [PVSaveState]
    let adjustedHeight: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @FocusState.Binding var focusedSaveState: String?
    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    var body: some View {
        let startIndex = pageIndex * 2
        let endIndex = min(startIndex + 2, filteredSaveStates.count)

        ForEach(startIndex..<endIndex, id: \.self) { index in
            if index < filteredSaveStates.count {
                ContinueItemWrapper(
                    saveState: filteredSaveStates[index],
                    height: adjustedHeight,
                    hideSystemLabel: hideSystemLabel,
                    rootDelegate: rootDelegate,
                    focusedSaveState: $focusedSaveState,
                    parentFocusedSection: $parentFocusedSection,
                    parentFocusedItem: $parentFocusedItem
                )
            }
        }
    }
}

private struct PortraitGridContent: View {
    let pageIndex: Int
    let filteredSaveStates: [PVSaveState]
    let adjustedHeight: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @FocusState.Binding var focusedSaveState: String?
    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    var body: some View {
        if pageIndex < filteredSaveStates.count {
            ContinueItemWrapper(
                saveState: filteredSaveStates[pageIndex],
                height: adjustedHeight,
                hideSystemLabel: hideSystemLabel,
                rootDelegate: rootDelegate,
                focusedSaveState: $focusedSaveState,
                parentFocusedSection: $parentFocusedSection,
                parentFocusedItem: $parentFocusedItem
            )
        }
    }
}

private struct ContinueItemWrapper: View {
    let saveState: PVSaveState
    let height: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @FocusState.Binding var focusedSaveState: String?
    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    var body: some View {
        HomeContinueItemView(
            continueState: saveState,
            height: height,
            hideSystemLabel: hideSystemLabel,
            action: {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(
                        saveState.game,
                        sender: self,
                        core: saveState.core,
                        saveState: saveState
                    )
                }
            },
            isFocused: focusedSaveState == saveState.id
        )
        .focusableIfAvailable()
        .focused($focusedSaveState, equals: saveState.id)
        .onChange(of: focusedSaveState) { newValue in
            if newValue != nil {
                parentFocusedSection = .recentSaveStates
                parentFocusedItem = newValue
            }
        }
    }
}

private struct EmptyContinuesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Text("No Continues")
            .tag("no continues")
            .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
    }
}

#endif

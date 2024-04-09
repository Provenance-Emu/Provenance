//
//  ConsoleGamesView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary

// TODO: might be able to reuse this view for collections
@available(iOS 14, tvOS 14, *)
struct ConsoleGamesView: SwiftUI.View {

    @ObservedObject var viewModel: PVRootViewModel
    let console: PVSystem
    weak var rootDelegate: PVRootDelegate?

    @ObservedResults(
        PVGame.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var games

//    @ObservedResults(
//        PVGame.self,
//        filter: NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier])
//        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
//    ) var filteredGames

    init(console: PVSystem, viewModel: PVRootViewModel, rootDelegate: PVRootDelegate? = nil) {
        self.console = console
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate
    }

    func filteredAndSortedGames() -> Results<PVGame> {
        // TODO: if filters are on, apply them here before returning
        return games
            .filter(NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier]))
            .sorted(by: [SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: viewModel.sortGamesAscending)])
    }

    // Adjustable grid size via pinch
    // from; https://github.com/AlexanderMarchant/DynamicGridZoom/tree/main
    @State var scale: CGFloat = 1.0

    // Multiple of how much to decrease the existing size to equal the next decreased size
    @State var scaleFactor: CGFloat = 1.0

    // Multiple of how much to increase the existing size to equal the next increased size
    @State var zoomFactor: CGFloat = 1.0

    @State var isMagnifying = false

    @State private var size: CGFloat = 100

    @State private var currentZoomStageIndex = 2
    @State private var previousZoomStageUpdateState: CGFloat = 0
    @State private var adjustedState: CGFloat = 0

    @State private var gridWidth: CGFloat = 0
    @State private var zooming: Bool = false

    @State private var padding: CGFloat = 2

    var body: some SwiftUI.View {
        let columns = [
            GridItem(.adaptive(minimum: size), spacing: padding)
        ]
        return VStack {
            GamesDisplayOptionsView(
                sortAscending: viewModel.sortGamesAscending,
                isGrid: viewModel.viewGamesAsGrid,
                toggleFilterAction: { self.rootDelegate?.showUnderConstructionAlert() },
                toggleSortAction: { viewModel.sortGamesAscending.toggle() },
                toggleViewTypeAction: { viewModel.viewGamesAsGrid.toggle() })
            .padding(.top, 16)
            ScrollView {
                if viewModel.viewGamesAsGrid {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredAndSortedGames(), id: \.self) { game in
                            GameItemView(game: game) {
                                rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                            }
                            .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                        }
                    }
                    .padding(.horizontal, 10)
                } else {
                    LazyVStack {
                        ForEach(filteredAndSortedGames(), id: \.self) { game in
                            GameItemView(game: game, viewType: .row) {
                                rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                            }
                            .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                            GamesDividerView()
                        }
                    }
                    .padding(.horizontal, 10)
                }
                if console.bioses.count > 0 {
                    LazyVStack {
                        GamesDividerView()
                        ForEach(console.bioses, id: \.self) { bios in
                            BiosRowView(bios: bios.warmUp())
                            GamesDividerView()
                        }
                    }
                    .background(Theme.currentTheme.settingsCellBackground?.swiftUIColor.opacity(0.3) ?? Color.black)
                }
            }
            //        .scrollDisabled(self.zooming)
            .scaleEffect(scale, anchor: .top)
            .background(
                GeometryReader { proxy in
                    Theme.currentTheme.gameLibraryBackground.swiftUIColor
                        .onAppear {
                            self.gridWidth = proxy.frame(in: .local).width
                            self.calculateZoomFactor(at: self.currentZoomStageIndex)
                        }
                }
            )
            #if !os(tvOS)
            .gesture(
                MagnificationGesture()
                .onChanged { state in

                    // Adjust state so we are always working from 1 because we are changing layouts whilst magnifying
                    var adjustedState = state - self.previousZoomStageUpdateState

                    self.zooming = true

                    // Decreasing the size
                    if scale <= 1,
                       adjustedState < 1
                    {
                        self.isMagnifying = false
                        if self.currentZoomStageIndex > GridZoomStages.zoomStages.count - 1
                        {
                            if adjustedState > 0.95
                            {
                                self.scale = self.scaleFactor - (1 - adjustedState)
                            }
                            else
                            {
                                // If the user is at the upper limit of stages, cap the magnification
                                adjustedState = 0.95
                            }
                        }
                        else
                        {
                            // Minimise the size of the elements based on the number of items to show per-line
                            let updatedSize = self.calculateUpdatedSize(index: self.currentZoomStageIndex + 1)

                            self.previousZoomStageUpdateState = state - 1

                            self.zoomFactor = updatedSize / self.size
                            self.scaleFactor = self.size / updatedSize

                            // Setting the scale to the scale factor between sizes ensures the user doesn't see a 'jump' between stages
                            self.scale = self.scaleFactor

                            self.size = updatedSize

                            self.currentZoomStageIndex = self.currentZoomStageIndex + 1
                        }
                    }
                    // Increasing the size
                    else if scale >= self.zoomFactor,
                            adjustedState > 1
                    {
                        self.isMagnifying = true
                        if self.currentZoomStageIndex == 0
                        {
                            if adjustedState < 1.1
                            {
                                self.scale = 1 - (1 - adjustedState)
                            }
                            else
                            {
                                // If the user is at the lower limit of stages, cap the magnification
                                adjustedState = 1.1
                            }
                        }
                        else
                        {
                            self.currentZoomStageIndex = self.currentZoomStageIndex - 1
                            self.previousZoomStageUpdateState = state - 1

                            self.calculateZoomFactor(at: self.currentZoomStageIndex)

                            self.scaleFactor = 1

                            // Setting the scale 1 ensures the user doesn't see a 'jump' between zoomed stages
                            self.scale = 1
                        }
                    }
                    else
                    {
                        if self.isMagnifying
                        {
                            self.scale = 1 - (1 - adjustedState)
                        }
                        else
                        {
                            self.scale = self.scaleFactor - (1 - adjustedState)
                        }
                    }

                    self.adjustedState = adjustedState
                }
                .onEnded { _ in

                    let shouldMagnify = self.adjustedState > 1
                    let animationDuration = 0.25

                    withAnimation(.linear(duration: animationDuration))
                    {
                        if shouldMagnify
                        {
                            // Continue zooming until it reaches limit for the next stage
                            self.scale = self.zoomFactor
                        }
                        else
                        {
                            self.resetZoomVariables()
                        }
                    }

                    if shouldMagnify
                    {
                        // Delay reset so zooming finishes and it smoothly transitions to the next zoom stage
                        // This mimics the behaviour a user see's if they were to manually transition between stages by zooming
                        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration)
                        {
                            if self.currentZoomStageIndex > 0
                            {
                                self.currentZoomStageIndex = self.currentZoomStageIndex - 1
                            }

                            self.resetZoomVariables()
                        }
                    }
                }
            )
            #endif
        }
    }
    // MARK: Adjustable size helpers
    func resetZoomVariables() {
        self.calculateZoomFactor(at: self.currentZoomStageIndex)
        self.zooming = false
        self.scale = 1
        self.scaleFactor = 1
        self.previousZoomStageUpdateState = 0
        self.adjustedState = 0
    }

    func calculateUpdatedSize(index: Int) -> CGFloat {
        let zoomStages = GridZoomStages.getZoomStage(at: index)

        let availableSpace = self.gridWidth - (2 * CGFloat(zoomStages))

        return availableSpace / CGFloat(zoomStages)
    }

    func calculateZoomFactor(at index: Int) {
        let currentSize = self.calculateUpdatedSize(index: index)
        let magnifiedSize = self.calculateUpdatedSize(index: index - 1)

        self.zoomFactor = magnifiedSize / currentSize

        self.size = currentSize
    }
}

@available(iOS 14, tvOS 14, *)
struct ConsoleGamesView_Previews: PreviewProvider {
    static let console: PVSystem = ._rlmDefaultValue()
    static let viewModel: PVRootViewModel = .init()

    static var previews: some SwiftUI.View {
        ConsoleGamesView(console: console,
                         viewModel: viewModel, 
                         rootDelegate: nil)
    }
}

struct GridZoomStages
{
    static var zoomStages: [Int]
    {
        #if os(tvOS)
        return [1, 2, 4, 8, 16]
        #else
        if UIDevice.current.userInterfaceIdiom == .pad
        {
            if UIDevice.current.orientation.isLandscape
            {
                return [4, 6, 10, 14, 18]
            }
            else
            {
                return [4, 6, 8, 10, 12]
            }
        }
        else
        {
            if UIDevice.current.orientation.isLandscape
            {
                return [4, 6, 8, 9]
            }
            else
            {
                return [1, 2, 4, 6, 8]
            }
        }
        #endif
    }

    static func getZoomStage(at index: Int) -> Int
    {
        if index >= zoomStages.count
        {
            return zoomStages.last!
        }
        else if index < 0
        {
            return zoomStages.first!
        }
        else
        {
            return zoomStages[index]
        }
    }
}
#endif

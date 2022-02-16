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
    var console: PVSystem
    var rootDelegate: PVRootDelegate?
    
    @ObservedResults(
        PVGame.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var games
    
    init(console: PVSystem, viewModel: PVRootViewModel, rootDelegate: PVRootDelegate) {
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
    
    // TODO: adjust for landscape
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    
    var body: some SwiftUI.View {
        ScrollView {
            GamesDisplayOptionsView(
                sortAscending: viewModel.sortGamesAscending,
                isGrid: viewModel.viewGamesAsGrid,
                toggleFilterAction: { self.rootDelegate?.showUnderConstructionAlert() },
                toggleSortAction: { viewModel.sortGamesAscending.toggle() },
                toggleViewTypeAction: { viewModel.viewGamesAsGrid.toggle() })
                .padding(.top, 16)
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
        .background(Theme.currentTheme.gameLibraryBackground.swiftUIColor)
    }
}

@available(iOS 14, tvOS 14, *)
struct BiosRowView: SwiftUI.View {
    
    var bios: PVBIOS
    
    func biosState() -> BIOSStatus.State {
        return (bios as BIOSStatusProvider).status.state
    }
    
    var body: some SwiftUI.View {
        HStack(alignment: .center, spacing: 0) {
            Image(biosState().biosStatusImageName).resizable().scaledToFit()
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
            VStack(alignment: .leading) {
                Text("\(bios.descriptionText)")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white)
                Text("\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
            }
            Spacer()
            HStack(alignment: .center, spacing: 4) {
                switch biosState() {
                case .match:
                    Image(systemName: "checkmark")
                        .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                        .font(.system(size: 13, weight: .light))
                case .missing:
                    Text("Missing")
                        .font(.system(size: 12))
                        .foregroundColor(Color.yellow)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.yellow)
                        .font(.system(size: 12, weight: .light))
                case let .mismatch(_):
                    Text("Mismatch")
                        .font(.system(size: 12))
                        .foregroundColor(Color.red)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.red)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
    }
}

extension BIOSStatus.State {
    var biosStatusImageName: String {
        switch self {
        case .missing: return "bios_empty"
        case .mismatch(_):  return "bios_empty"
        case .match: return "bios_filled"
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct GamesDividerView: SwiftUI.View {
    var body: some SwiftUI.View {
        Divider()
            .frame(height: 1)
            .background(Theme.currentTheme.gameLibraryText.swiftUIColor)
            .opacity(0.1)
    }
}

@available(iOS 14, tvOS 14, *)
struct GamesDisplayOptionsView: SwiftUI.View {
    
    var sortAscending = true
    var isGrid = true
    
    var toggleFilterAction: () -> Void
    var toggleSortAction: () -> Void
    var toggleViewTypeAction: () -> Void
    
    var body: some SwiftUI.View {
        HStack(spacing: 12) {
            Spacer()
            OptionsIndicator(pointDown: true, action: { toggleFilterAction() }) {
                Text("Filter").foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor).font(.system(size: 13))
            }
            OptionsIndicator(pointDown: sortAscending, action: { toggleSortAction() }) {
                Text("Sort").foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor).font(.system(size: 13))
            }
            OptionsIndicator(pointDown: true, action: { toggleViewTypeAction() }) {
                Image(systemName: isGrid == true ? "square.grid.3x3.fill" : "line.3.horizontal")
                    .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                    .font(.system(size: 13, weight: .light))
            }
            .padding(.trailing, 10)
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct OptionsIndicator<Content: SwiftUI.View>: SwiftUI.View {
    
    var pointDown: Bool = true
    var chevronSize: CGFloat = 12.0
    
    var action: () -> Void
    
    @ViewBuilder var label: () -> Content
    
    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 3) {
                label()
                Image(systemName: pointDown == true ? "chevron.down" : "chevron.up")
                    .foregroundColor(.gray)
                    .font(.system(size: chevronSize, weight: .ultraLight))
            }
        }
    }
}

//@available(iOS 14, tvOS 14, *)
//struct HomeView_Previews: PreviewProvider {
//    static var previews: some SwiftUI.View {
//        HomeView()
//    }
//}

#endif

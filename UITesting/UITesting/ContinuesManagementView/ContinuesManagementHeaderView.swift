//
//  ContinuesManagementHeaderView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes

/// View model for the header containing game information
public class ContinuesManagementHeaderViewModel: ObservableObject {
    let gameTitle: String
    let systemTitle: String
    @Published var numberOfSaves: Int
    let gameSize: Int
    let gameImage: Image

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public init(gameTitle: String, systemTitle: String, numberOfSaves: Int, gameSize: Int, gameImage: Image) {
        self.gameTitle = gameTitle
        self.systemTitle = systemTitle
        self.numberOfSaves = numberOfSaves
        self.gameSize = gameSize
        self.gameImage = gameImage
    }
}

public struct ContinuesManagementHeaderView: View {
    /// View model containing the header data
    @ObservedObject var viewModel: ContinuesManagementHeaderViewModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                viewModel.gameImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.gameTitle)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(viewModel.systemTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(viewModel.numberOfSaves) Save States - \(viewModel.gameSize) MB")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

//            Divider()
//                .padding(.top, 20)
        }
        .frame(height: 160) /// Fixed height for the header
    }
}

// MARK: - Previews

#Preview("Normal, Edit, and Auto-save States") {
    VStack(spacing: 20) {
        /// Normal mode
        let normalViewModel = ContinuesManagementHeaderViewModel(gameTitle: "Game 1", systemTitle: "System 1", numberOfSaves: 5, gameSize: 100, gameImage: Image("game1"))
        ContinuesManagementHeaderView(viewModel: normalViewModel)

        /// Edit mode
        let editViewModel = ContinuesManagementHeaderViewModel(gameTitle: "Game 2", systemTitle: "System 2", numberOfSaves: 10, gameSize: 150, gameImage: Image("game2"))
        ContinuesManagementHeaderView(viewModel: editViewModel)
            .onAppear {
                editViewModel.numberOfSaves = 10
            }

        /// Auto-saves enabled
        let autoSaveViewModel = ContinuesManagementHeaderViewModel(gameTitle: "Game 3", systemTitle: "System 3", numberOfSaves: 15, gameSize: 200, gameImage: Image("game3"))
        ContinuesManagementHeaderView(viewModel: autoSaveViewModel)
            .onAppear {
                autoSaveViewModel.numberOfSaves = 15
            }
    }
    .padding()
}

#if DEBUG
#Preview("Dark Mode") {
    ContinuesManagementHeaderView(viewModel: ContinuesManagementHeaderViewModel(gameTitle: "Game 4", systemTitle: "System 4", numberOfSaves: 20, gameSize: 250, gameImage: Image("game4")))
        .frame(width: 375)
        .padding()
}

#Preview("iPad Layout") {
    ContinuesManagementHeaderView(viewModel: ContinuesManagementHeaderViewModel(gameTitle: "Game 5", systemTitle: "System 5", numberOfSaves: 25, gameSize: 300, gameImage: Image("game5")))
        .frame(width: 744)
        .padding()
}
#endif

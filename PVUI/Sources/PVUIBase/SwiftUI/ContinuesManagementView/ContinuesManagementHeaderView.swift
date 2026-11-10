//
//  ContinuesManagementHeaderView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import SwiftUI
import PVThemes
import UIKit

/// View model for the header containing game information
public class ContinuesManagementHeaderViewModel: ObservableObject {
    let gameTitle: String
    let systemTitle: String
    @Published var numberOfSaves: Int
    @Published var savesTotalSize: Int
    @Published var gameUIImage: UIImage?

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    var gameImage: Image {
        if let uiImage = gameUIImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "gamecontroller")
    }

    public init(gameTitle: String, systemTitle: String, numberOfSaves: Int, savesTotalSize: Int, gameUIImage: UIImage? = nil) {
        self.gameTitle = gameTitle
        self.systemTitle = systemTitle
        self.numberOfSaves = numberOfSaves
        self.savesTotalSize = savesTotalSize
        self.gameUIImage = gameUIImage
    }
}

public struct ContinuesManagementHeaderView: View {
    /// View model containing the header data
    @ObservedObject var viewModel: ContinuesManagementHeaderViewModel

    /// Theme-aware color helpers
    private var primaryTextColor: Color {
        viewModel.currentPalette.gameLibraryText.swiftUIColor
    }

    private var secondaryTextColor: Color {
        if let detailText = viewModel.currentPalette.settingsCellTextDetail {
            return detailText.swiftUIColor
        }
        return viewModel.currentPalette.dark
            ? Color.grey.gEEE
            : Color.gray
    }

    /// Side of the square game artwork.
    static let artworkSize: CGFloat = 64
    /// Clears the sheet's drag indicator.
    static let topInset: CGFloat = 24
    /// Header height: short enough that a half-height sheet still shows several saves.
    static let height = topInset + artworkSize + RetroPauseChrome.chromeInset

    private var summary: String {
        let megabytes = String(format: "%.2f", Float(viewModel.savesTotalSize) / 1024.0 / 1024.0)
        return viewModel.numberOfSaves == 1
            ? String(localized: "1 Save State - \(megabytes) MB")
            : String(localized: "\(viewModel.numberOfSaves) Save States - \(megabytes) MB")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: RetroPauseChrome.chromeInset) {
                viewModel.gameImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Self.artworkSize, height: Self.artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: RetroPauseChrome.menuCellCornerRadius()))

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.gameTitle)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(viewModel.systemTitle)
                        .font(.subheadline)
                        .foregroundColor(primaryTextColor.opacity(0.8))

                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.horizontal, RetroPauseChrome.chromeInset)
            .padding(.top, Self.topInset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height, alignment: .top)
    }
}

// MARK: - Previews

#Preview("Normal, Edit, and Auto-save States") {
    VStack(spacing: 20) {
        /// Normal mode
        let normalViewModel = ContinuesManagementHeaderViewModel(gameTitle: "Game 1", systemTitle: "System 1", numberOfSaves: 5, savesTotalSize: 100, gameUIImage: UIImage(named: "game1"))
        ContinuesManagementHeaderView(viewModel: normalViewModel)

        /// Edit mode
        let editViewModel = ContinuesManagementHeaderViewModel(gameTitle: "Game 2", systemTitle: "System 2", numberOfSaves: 10, savesTotalSize: 150, gameUIImage: UIImage(named: "game2"))
        ContinuesManagementHeaderView(viewModel: editViewModel)
            .onAppear {
                editViewModel.numberOfSaves = 10
            }

        /// Auto-saves enabled
        let autoSaveViewModel = ContinuesManagementHeaderViewModel(gameTitle: "Game 3", systemTitle: "System 3", numberOfSaves: 15, savesTotalSize: 200, gameUIImage: UIImage(named: "game3"))
        ContinuesManagementHeaderView(viewModel: autoSaveViewModel)
            .onAppear {
                autoSaveViewModel.numberOfSaves = 15
            }
    }
    .padding()
}

#if DEBUG
#Preview("Dark Mode") {
    ContinuesManagementHeaderView(viewModel: ContinuesManagementHeaderViewModel(gameTitle: "Game 4", systemTitle: "System 4", numberOfSaves: 20, savesTotalSize: 250, gameUIImage: UIImage(named: "game4")))
        .frame(width: 375)
        .padding()
}

#Preview("iPad Layout") {
    ContinuesManagementHeaderView(viewModel: ContinuesManagementHeaderViewModel(gameTitle: "Game 5", systemTitle: "System 5", numberOfSaves: 25, savesTotalSize: 300, gameUIImage: UIImage(named: "game5")))
        .frame(width: 744)
        .padding()
}
#endif

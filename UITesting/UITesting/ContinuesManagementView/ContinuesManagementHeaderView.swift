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
    var currentArtwork: Image? { gameImage }
    var currentGameTitle: String { gameTitle }
    var lastPlayedDate: String = ""
    var saveCount: Int { numberOfSaves }

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
    var isCompact: Bool

    public var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if let artwork = viewModel.currentArtwork {
                artwork
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: isCompact ? 40 : 80, height: isCompact ? 40 : 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: isCompact ? 40 : 80, height: isCompact ? 40 : 80)
            }

            VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                Text(viewModel.currentGameTitle)
                    .font(.system(size: isCompact ? 16 : 20, weight: .bold))
                    .lineLimit(1)

                if !isCompact {
                    Text("Last played: \(viewModel.lastPlayedDate)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Text("\(viewModel.saveCount) saves")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isCompact)

            Spacer()
        }
        .padding(.horizontal)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCompact)
    }
}

// MARK: - Previews

#Preview("Normal and Compact States") {
    VStack(spacing: 20) {
        /// Normal mode
        let normalViewModel = ContinuesManagementHeaderViewModel(gameTitle: "Game 1", systemTitle: "System 1", numberOfSaves: 5, gameSize: 100, gameImage: Image("game1"))
        ContinuesManagementHeaderView(viewModel: normalViewModel, isCompact: false)
            .frame(height: 160)

        /// Compact mode
        ContinuesManagementHeaderView(viewModel: normalViewModel, isCompact: true)
            .frame(height: 70)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Dark Mode", traits: .defaultLayout) {
    ContinuesManagementHeaderView(
        viewModel: ContinuesManagementHeaderViewModel(
            gameTitle: "Game 4",
            systemTitle: "System 4",
            numberOfSaves: 20,
            gameSize: 250,
            gameImage: Image("game4")
        ),
        isCompact: false
    )
    .frame(width: 375)
    .padding()
}

#Preview("iPad Layout") {
    ContinuesManagementHeaderView(
        viewModel: ContinuesManagementHeaderViewModel(
            gameTitle: "Game 5",
            systemTitle: "System 5",
            numberOfSaves: 25,
            gameSize: 300,
            gameImage: Image("game5")
        ),
        isCompact: false
    )
    .frame(width: 744)
    .padding()
}

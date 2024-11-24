//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PopupView
import ScalingHeaderScrollView
import AnimatedGradient
import PVThemes


/// View model for the main continues management view
public class ContinuesMagementViewModel: ObservableObject {
    /// Header view model
    @Published var headerViewModel: ContinuesManagementHeaderViewModel
    /// Controls view model
    @Published var controlsViewModel: ContinuesManagementListControlsViewModel
    @Published var saveStates: [SaveStateRowViewModel]

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public init(gameTitle: String, systemTitle: String, numberOfSaves: Int, gameSize: Int, gameImage: Image) {
        self.headerViewModel = ContinuesManagementHeaderViewModel(
            gameTitle: gameTitle,
            systemTitle: systemTitle,
            numberOfSaves: numberOfSaves,
            gameSize: gameSize,
            gameImage: gameImage
        )
        self.controlsViewModel = ContinuesManagementListControlsViewModel()

        /// Initialize with sample data
        self.saveStates = [
            SaveStateRowViewModel(
                gameTitle: gameTitle,
                saveDate: Date(),
                thumbnailImage: gameImage,
                description: "Latest Save"
            ),
            SaveStateRowViewModel(
                gameTitle: gameTitle,
                saveDate: Date().addingTimeInterval(-3600),
                thumbnailImage: gameImage
            )
        ]
    }
}

public struct ContinuesMagementView: View {
    /// Main view model
    @StateObject private var viewModel: ContinuesMagementViewModel
    @State var showingPopup = false
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public init(viewModel: ContinuesMagementViewModel = ContinuesMagementViewModel(
        gameTitle: "Game Title",
        systemTitle: "System Title",
        numberOfSaves: 5,
        gameSize: 100,
        gameImage: Image(systemName: "gamecontroller"))
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            /// Header view
            VStack {
                ZStack {
                    AnimatedLinearGradient(colors: [
                        .Provenance.blue,
                        currentPalette.settingsCellBackground!.swiftUIColor,
                        currentPalette.gameLibraryBackground.swiftUIColor,
                        currentPalette.settingsCellBackground!.swiftUIColor])
                    .numberOfSimultaneousColors(2)
                    .setAnimation(.bouncy(duration: 10))
                    .gradientPoints(start: .bottomLeading, end: .topTrailing)
                    .padding(.bottom, 10)
                    .opacity(0.25)

                    ContinuesManagementHeaderView(viewModel: viewModel.headerViewModel)
                }
                .frame(height: 160)
                .shadow(radius: 5)
            }
            .clipShape(RoundedCorners(radius: 20, corners: [.bottomLeft, .bottomRight]))

            /// List view
            ZStack {
                AnimatedLinearGradient(colors: [
                    .Provenance.blue,
                    currentPalette.settingsCellBackground!.swiftUIColor,
                    currentPalette.gameLibraryBackground.swiftUIColor,
                    currentPalette.settingsCellBackground!.swiftUIColor])
                .numberOfSimultaneousColors(2)
                .setAnimation(.bouncy(duration: 10))
                .gradientPoints(start: .topTrailing, end: .bottomLeading)
                .padding(.bottom, 10)
                .opacity(0.25)
                ContinuesManagementContentView(viewModel: viewModel)
            }
            .background(currentPalette.settingsCellBackground!.swiftUIColor)
            .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))

        }
        .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))
//        .background(currentPalette.settingsCellBackground!.swiftUIColor)
        .padding()
    }
}

/// Custom shape for top-only rounded corners
struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview("Continues Management") {
    /// Sample view model for preview
    let sampleViewModel = ContinuesMagementViewModel(
        gameTitle: "Bomber Man",
        systemTitle: "Game Boy",
        numberOfSaves: 34,
        gameSize: 15,
        gameImage: Image(systemName: "gamecontroller") /// Using SF Symbol as placeholder
    )

    ContinuesMagementView(viewModel: sampleViewModel)
        .onAppear {
            let theme =  CGAThemes.magenta
            ThemeManager.shared.setCurrentPalette(theme.palette)
        }
}

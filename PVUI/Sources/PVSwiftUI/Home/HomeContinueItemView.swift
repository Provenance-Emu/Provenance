//
//  HomeContinueItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVThemes
import RealmSwift

struct HomeContinueItemView: SwiftUI.View {

    @ObservedRealmObject var continueState: PVSaveState
    let height: CGFloat
    let hideSystemLabel: Bool
    var action: () -> Void

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            ZStack {
                if let screenshot = continueState.image, let image = UIImage(contentsOfFile: screenshot.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: height)
                } else {
                    Image(uiImage: UIImage.missingArtworkImage(gameTitle: continueState.game.title, ratio: 1))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: height)
                }
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Continue...")
                                .font(.system(size: 10))
                                .foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
                            Text(continueState.game.title)
                                .font(.system(size: 13))
                                .foregroundColor(Color.white)
                        }
                        Spacer()
                        if !hideSystemLabel {
                            VStack(alignment: .trailing) {
                                Text("...").font(.system(size: 15)).opacity(0)
                                Text(continueState.game.system.name)
                                    .font(.system(size: 8))
                                    .foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}

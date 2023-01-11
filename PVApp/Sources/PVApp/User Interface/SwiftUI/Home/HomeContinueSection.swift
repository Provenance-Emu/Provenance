//
//  HomeContinueSection.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/1/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import RealmSwift
import PVLibrary

@available(iOS 15, tvOS 15, *)
struct HomeContinueSection: SwiftUI.View {

    var continueStates: Results<PVSaveState>
    weak var rootDelegate: PVRootDelegate?
    let height: CGFloat = 260

    var body: some SwiftUI.View {
        TabView {
            if continueStates.count > 0 {
                ForEach(continueStates, id: \.self) { state in
                    HomeContinueItemView(continueState: state, height: height) {
                        rootDelegate?.root_load(state.game, sender: self, core: state.core, saveState: state)
                    }
                }
            } else {
                Text("No Continues")
                    .tag("no continues")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(continueStates.count)
        .frame(height: height)
    }
}

@available(iOS 15, tvOS 15, *)
struct HomeContinueItemView: SwiftUI.View {

    @ObservedRealmObject var continueState: PVSaveState
    let height: CGFloat // match image height to section height, else the fill content mode messes up the zstack
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
                                .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                            Text(continueState.game.title)
                                .font(.system(size: 13))
                                .foregroundColor(Color.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("...").font(.system(size: 15)).opacity(0)
                            Text(continueState.game.system.name)
                                .font(.system(size: 8))
                                .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
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

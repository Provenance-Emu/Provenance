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
    @ObservedObject private var themeManager = ThemeManager.shared
    let height: CGFloat
    let hideSystemLabel: Bool
    var action: () -> Void

    @State private var showDeleteAlert = false

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
                    Image(uiImage: UIImage.missingArtworkImage(gameTitle: continueState.game?.title ?? "Deleted", ratio: 1))
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
                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            Text(continueState.game.title)
                                .font(.system(size: 13))
                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        }
                        Spacer()
                        if !hideSystemLabel {
                            VStack(alignment: .trailing) {
                                Text(continueState.game.system?.name ?? "")
                                    .font(.system(size: 8))
                                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete Save State", systemImage: "trash")
            }
        }
        .alert("Delete Save State", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                do {
                    try RomDatabase.sharedInstance.delete(saveState: continueState)
                } catch {
                    ELOG("Failed to delete save state: \(error.localizedDescription)")
                }
            }
        } message: {
            Text("Are you sure you want to delete this save state for \(continueState.game.title)?")
        }
    }
}

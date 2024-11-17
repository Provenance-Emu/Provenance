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
    let isFocused: Bool

    @State private var showDeleteAlert = false

    var body: some SwiftUI.View {
        if !continueState.isInvalidated {
            Button {
                action()
            } label: {
                ZStack(alignment: .bottom) {
                    if let screenshot = continueState.image,
                       !screenshot.isInvalidated,
                       let image = UIImage(contentsOfFile: screenshot.url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: height)
                            .frame(maxWidth: .infinity)
                    } else {
                        Image(uiImage: UIImage.missingArtworkImage(gameTitle: continueState.game?.title ?? "Deleted", ratio: 1))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: height)
                            .frame(maxWidth: .infinity)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let core = continueState.core {
                                Text("\(core.projectName): Continue...")
                                    .font(.system(size: 10))
                                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            } else {
                                Text("Continue...")
                                    .font(.system(size: 10))
                                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            }
                            Text(continueState.game?.isInvalidated == true ? "Deleted" : (continueState.game?.title ?? "Deleted"))
                                .font(.system(size: 13))
                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        }
                        Spacer()
                        if !hideSystemLabel, let system = continueState.game?.system, !system.isInvalidated {
                            Text(system.name)
                                .font(.system(size: 8))
                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                    .frame(maxWidth: .infinity)
                }
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .brightness(isFocused ? 0.1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
            }
            .contextMenu {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Save State", systemImage: "trash")
                }
            }
            .uiKitAlert(
                "Delete Save State",
                message: "Are you sure you want to delete this save state for \(continueState.game?.isInvalidated == true ? "this game" : continueState.game?.title ?? "Deleted")?",
                isPresented: $showDeleteAlert,
                preferredContentSize: CGSize(width: 500, height: 300)
            ) {
                UIAlertAction(title: "Delete", style: .destructive) { _ in
                    do {
                        try RomDatabase.sharedInstance.delete(saveState: continueState)
                    } catch {
                        ELOG("Failed to delete save state: \(error.localizedDescription)")
                    }
                    showDeleteAlert = false
                }
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    showDeleteAlert = false
                }
            }
        }
    }
}

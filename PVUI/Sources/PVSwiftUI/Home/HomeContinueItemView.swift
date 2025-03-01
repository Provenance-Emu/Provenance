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

    /// Constants for CRT effects
    internal enum CRTEffects {
        // Scanline effects
        static let scanlineOpacity: CGFloat = 0.3
        static let lcdOpacity: CGFloat = 0.1

        // Image presentation
        static let zoomFactor: CGFloat = 1.15
    }

    var body: some SwiftUI.View {
        if !continueState.isInvalidated {
            Button {
                action()
            } label: {
                ZStack(alignment: .top) {
                    if let screenshot = continueState.image,
                       !screenshot.isInvalidated,
                       let url = screenshot.url,
                       let image = UIImage(contentsOfFile: url.path) {
                        baseImageLayer(image)
                            .drawingGroup() // Use Metal rendering
                            .overlay(RetroEffects())
                    } else {
                        Image(uiImage: UIImage.missingArtworkImage(gameTitle: continueState.game?.title ?? "Deleted", ratio: 1))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: height * CRTEffects.zoomFactor)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(CRTEffects.zoomFactor)
                            .clipped()
                            .drawingGroup() // Use Metal rendering
                            .overlay(RetroEffects())
                            .id(themeManager.currentPalette.name)
                    }
                }
                .frame(height: height)
                .clipShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(themeManager.currentPalette.gameLibraryText.swiftUIColor, lineWidth: isFocused ? 4 : 0)
                )
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

    @ViewBuilder
    private func baseImageLayer(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: height * CRTEffects.zoomFactor)
            .frame(maxWidth: .infinity)
            .scaleEffect(CRTEffects.zoomFactor)
            .clipped()
    }
}

/// Combined retro effects overlay
private struct RetroEffects: View {
    var body: some View {
        ZStack {
            // Scanlines
            GeometryReader { geometry in
                Path { path in
                    stride(from: 0, to: geometry.size.height, by: 2).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(.black.opacity(HomeContinueItemView.CRTEffects.scanlineOpacity), lineWidth: 1)
            }

            // LCD effect (vertical lines)
            GeometryReader { geometry in
                Path { path in
                    stride(from: 0, to: geometry.size.width, by: 3).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                }
                .stroke(.black.opacity(HomeContinueItemView.CRTEffects.lcdOpacity), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

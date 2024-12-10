//
//  GameArtworkView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI
import UIKit

/// View for displaying and interacting with game artwork
struct GameArtworkView: View {
    let frontArtwork: UIImage?
    let backArtwork: UIImage?
    let aspectRatio: CGFloat
    @State private var isShowingBack = false
    @State private var isShowingFullscreen = false

    var body: some View {
        ZStack {
            // Main artwork view
            artworkImage
                .rotation3DEffect(
                    .degrees(isShowingBack ? 180 : 0),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isShowingBack.toggle()
                    }
                }
                .onTapGesture(count: 2) {
                    isShowingFullscreen = true
                }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: 300)
        .fullScreenCover(isPresented: $isShowingFullscreen) {
            FullscreenArtworkView(
                image: isShowingBack ? backArtwork : frontArtwork,
                isShowingBack: $isShowingBack
            )
        }
    }

    private var artworkImage: some View {
        Group {
            if let image = isShowingBack ? backArtwork : frontArtwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 3)
    }
}

//
//  GameArtworkView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI
import UIKit

/// A view that displays game artwork with optional flipping between front and back artwork
struct GameArtworkView: View {
    let frontArtwork: UIImage?
    let backArtwork: UIImage?
    @State private var showingFrontArt = true
    @State private var isAnimating = false
    @State private var showingFullscreen = false

    private var canShowBackArt: Bool {
        backArtwork != nil
    }

    private var currentArtwork: UIImage? {
        showingFrontArt ? frontArtwork : (backArtwork?.withHorizontallyFlippedOrientation())
    }

    var body: some View {
        Image(uiImage: currentArtwork ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
#if !os(tvOS)
            .background(Color(.systemBackground))
        #endif
            .cornerRadius(8)
            .shadow(radius: 3)
            .padding()
            .rotation3DEffect(
                .degrees(showingFrontArt ? 0 : 180),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .animation(.easeInOut(duration: isAnimating ? 0.4 : 0), value: showingFrontArt)
            .onTapGesture(count: 2) {
                showingFullscreen = true
            }
            .onTapGesture {
                if canShowBackArt {
                    isAnimating = true
                    showingFrontArt.toggle()
                }
            }
            .onAppear {
                // Reset to front on appear
                showingFrontArt = true
                isAnimating = false
            }
            .fullScreenCover(isPresented: $showingFullscreen) {
                FullscreenArtworkView(
                    frontImage: frontArtwork,
                    backImage: backArtwork?.withHorizontallyFlippedOrientation()
                )
            }
    }
}

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

    private var canShowBackArt: Bool {
        backArtwork != nil
    }

    var body: some View {
        Image(uiImage: showingFrontArt ? (frontArtwork ?? UIImage()) : (backArtwork ?? frontArtwork ?? UIImage()))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .rotation3DEffect(
                .degrees(showingFrontArt ? 0 : 180),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .animation(.easeInOut(duration: isAnimating ? 0.4 : 0), value: showingFrontArt)
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
    }
}

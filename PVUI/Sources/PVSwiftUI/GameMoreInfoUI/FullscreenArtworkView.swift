//
//  FullscreenArtworkView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI
import UIKit

/// Fullscreen view for artwork with zoom and pan
struct FullscreenArtworkView: View {
    let frontImage: UIImage?
    let backImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var dragOffset = CGSize.zero
    @State private var showingFrontImage = true
    @State private var isAnimating = false
    @GestureState private var isDragging = false

    private let maxZoom: CGFloat = 3.0
    private let defaultZoom: CGFloat = 1.0

    private var currentImage: UIImage? {
        showingFrontImage ? frontImage : backImage
    }

    private var canFlip: Bool {
        backImage != nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset.width + dragOffset.width,
                               y: offset.height + dragOffset.height)
                        .rotation3DEffect(
                            .degrees(showingFrontImage ? 0 : 180),
                            axis: (x: 0.0, y: 1.0, z: 0.0)
                        )
                        .animation(.easeInOut(duration: isAnimating ? 0.4 : 0), value: showingFrontImage)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value.magnitude
                                    scale = min(max(defaultZoom, newScale), maxZoom)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .gesture(
                            DragGesture()
                                .updating($isDragging) { _, state, _ in
                                    state = true
                                }
                                .onChanged { value in
                                    if scale == defaultZoom {
                                        dragOffset = value.translation
                                    } else {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    if scale == defaultZoom {
                                        if abs(dragOffset.height) > 100 {
                                            dismiss()
                                        }
                                        dragOffset = .zero
                                    } else {
                                        lastOffset = offset
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > defaultZoom {
                                    // Reset to default
                                    scale = defaultZoom
                                    lastScale = defaultZoom
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    // Zoom in
                                    scale = maxZoom
                                    lastScale = maxZoom
                                }
                            }
                        }
                        .onTapGesture {
                            if canFlip {
                                isAnimating = true
                                showingFrontImage.toggle()
                            }
                        }
                }
            }
            .opacity(1.0 - (abs(dragOffset.height) / 500.0))
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}

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
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var dragOffset = CGSize.zero
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset.width + dragOffset.width,
                               y: offset.height + dragOffset.height)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value.magnitude
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
                                    if scale == 1.0 {
                                        dragOffset = value.translation
                                    } else {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    if scale == 1.0 {
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
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
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

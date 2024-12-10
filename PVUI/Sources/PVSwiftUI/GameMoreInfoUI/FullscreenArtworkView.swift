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
    @Binding var isShowingBack: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)

                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
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
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
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
            }
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

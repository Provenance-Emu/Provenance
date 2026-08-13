//
//  CachedAsyncImageView.swift
//  PVUI
//
//  Created by Cascade on 8/1/25.
//

import SwiftUI
import UIKit
import PVUIBase

/// Sizing policy for save-state screenshot thumbnails.
///
/// Save-state screenshots are captured at full device resolution and stored
/// without downscaling, so a single one decodes to ~12 MB. These views draw
/// them at 44-48pt in list rows and inside a Continue card — decoding at the
/// source resolution was the single largest contributor to resident
/// "Image IO" memory on the Home screen.
private enum ScreenshotThumbnailSizing {

    /// Screenshots are drawn `.fill` in a frame that is wider than it is tall.
    /// Allow for a 16:9 landscape source plus headroom for cards that stretch
    /// to the container width.
    static let aspectAllowance: CGFloat = 2.5

    /// Hard ceiling on the decoded long edge. Even the largest Continue card
    /// never needs more, and it keeps one entry under ~2.5 MB decoded.
    static let maxPixelSizeCeiling: CGFloat = 1024

    /// Floor, so a tiny row still gets a legible thumbnail on a 3x display.
    static let minPixelSize: CGFloat = 128

    static func maxPixelSize(height: CGFloat, zoomFactor: CGFloat, scale: CGFloat) -> Int {
        let target = height * zoomFactor * aspectAllowance * scale
        return Int(min(max(target, minPixelSize), maxPixelSizeCeiling).rounded(.up))
    }
}

struct CachedAsyncImageView: View {
    let url: URL?
    let fallbackImage: UIImage
    let height: CGFloat
    let zoomFactor: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    /// Decode budget for this presentation, derived from the frame it draws in.
    private var maxPixelSize: Int {
        ScreenshotThumbnailSizing.maxPixelSize(
            height: height,
            zoomFactor: zoomFactor,
            scale: displayScale
        )
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height * zoomFactor)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(zoomFactor)
                    .clipped()
            } else {
                Image(uiImage: fallbackImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height * zoomFactor)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(zoomFactor)
                    .clipped()
                    .opacity(isLoading ? 0.7 : 1.0)
            }
        }
        .task {
            await loadImageIfNeeded()
        }
        .onChange(of: url) { _ in
            Task {
                await loadImageIfNeeded()
            }
        }
    }

    private func loadImageIfNeeded() async {
        guard let url = url else { return }
        let budget = maxPixelSize

        // Check cache first
        if let cachedImage = FileThumbnailCache.shared.cachedImage(atPath: url.path, maxPixelSize: budget) {
            await MainActor.run {
                self.loadedImage = cachedImage
            }
            return
        }

        await MainActor.run {
            isLoading = true
        }

        // Load asynchronously — decoded off the main actor and downsampled.
        let image = await FileThumbnailCache.shared.image(atPath: url.path, maxPixelSize: budget)

        await MainActor.run {
            self.loadedImage = image
            self.isLoading = false
        }
    }
}

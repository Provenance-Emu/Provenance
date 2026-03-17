//
//  SkinPreviewCell.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/25.
//

import SwiftUI
import PVLogging

/// Preview cell for a skin with rubber-like design.
///
/// Loads the skin image asynchronously on a background thread and renders a
/// lightweight static thumbnail rather than a full ``DeltaSkinView``.
struct SkinPreviewCell: View {
    let skin: any DeltaSkinProtocol
    let manager: DeltaSkinManager
    var orientation: DeltaSkinOrientation = .portrait

    @State private var showingDeleteAlert = false
    @State private var deleteError: Error?
    @State private var showingErrorAlert = false
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = true
    @State private var thumbnailFailed = false
    #if !os(tvOS)
    @State private var showingShareSheet = false
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    // Rubber-like colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.85)
    }

    private var innerShadowColor: Color {
        colorScheme == .dark ? .black : Color(white: 0.7)
    }

    private var embossHighlightColor: Color {
        colorScheme == .dark ? Color(white: 0.25) : Color.white
    }

    /// Resolve the best supported traits for preview, trying progressively
    /// wider fallbacks so skins that only support one device/orientation
    /// still render a thumbnail.
    private var previewTraits: DeltaSkinTraits {
        let device: DeltaSkinDevice = horizontalSizeClass == .regular ? .ipad : .iphone
        let altDevice: DeltaSkinDevice = device == .ipad ? .iphone : .ipad
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        let oppositeOrientation: DeltaSkinOrientation = orientation == .portrait ? .landscape : .portrait

        // 1. Current device, requested orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: device, displayType: displayType, orientation: orientation)
            if skin.supports(traits) { return traits }
        }

        // 2. Current device, opposite orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: device, displayType: displayType, orientation: oppositeOrientation)
            if skin.supports(traits) { return traits }
        }

        // 3. Alternate device, requested orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: altDevice, displayType: displayType, orientation: orientation)
            if skin.supports(traits) { return traits }
        }

        // 4. Alternate device, opposite orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: altDevice, displayType: displayType, orientation: oppositeOrientation)
            if skin.supports(traits) { return traits }
        }

        // Final fallback (should rarely be reached)
        return DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)
    }

    var body: some View {
        ZStack {
            // Preview content with disabled interaction
            content
                .allowsHitTesting(false)

            // Transparent overlay to capture context menu
            Color.clear
                .contentShape(Rectangle())
        }
        .contextMenu {
            #if !os(tvOS)
            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            #endif

            if manager.isDeletable(skin) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .retroAlert("Delete Skin?",
                    message: "Are you sure you want to delete '\(skin.name)'? This cannot be undone.",
                    isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await manager.deleteSkin(skin.identifier)
                    } catch {
                        deleteError = error
                        showingErrorAlert = true
                    }
                }
            }
        }
        .retroAlert("Delete Error",
                    message: deleteError?.localizedDescription ?? "",
                    isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        }
        #if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [skin.fileURL])
        }
        #endif
        .onAppear {
            loadThumbnail()
        }
    }

    // MARK: - Thumbnail preview

    @ViewBuilder
    private var thumbnailPreview: some View {
        if isLoadingThumbnail {
            ProgressView()
                .frame(maxWidth: .infinity)
                .aspectRatio(orientation == .portrait ? 0.5 : 2.0, contentMode: .fit)
        } else if let thumbnailImage {
            Image(uiImage: thumbnailImage)
                .resizable()
                .scaledToFit()
                .aspectRatio(orientation == .portrait ? 0.5 : 2.0, contentMode: .fit)
        } else {
            // Fallback for skins where image loading failed
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(skin.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(orientation == .portrait ? 0.5 : 2.0, contentMode: .fit)
            .background(Color.gray.opacity(0.15))
        }
    }

    private func loadThumbnail() {
        let traits = previewTraits
        let cacheKey = "\(skin.identifier)-\(traits.device.rawValue)-\(traits.displayType.rawValue)-\(traits.orientation.rawValue)"

        // Fast path: use SkinSelectionPreviewCell's shared cache
        if let cached = SkinPreviewThumbnailCache.shared.thumbnail(forKey: cacheKey) {
            thumbnailImage = cached
            isLoadingThumbnail = false
            return
        }

        Task.detached(priority: .utility) {
            do {
                let image = try await skin.image(for: traits)
                SkinPreviewThumbnailCache.shared.store(image, forKey: cacheKey)
                await MainActor.run {
                    self.thumbnailImage = image
                    self.isLoadingThumbnail = false
                }
            } catch {
                ELOG("skins: SkinPreviewCell failed to load thumbnail for '\(skin.name)' traits=\(traits.description): \(error)")
                await MainActor.run {
                    self.thumbnailFailed = true
                    self.isLoadingThumbnail = false
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview — lightweight async thumbnail instead of full DeltaSkinView
            PreviewContainer {
                thumbnailPreview
            }
            .overlay {
                // Rubber-like gradient overlay
                LinearGradient(
                    colors: [
                        .black.opacity(0.4),
                        .clear,
                        .black.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(skin.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Label(skin.gameType.systemIdentifier?.fullName ?? (skin.gameType.deltaIdentifierString ?? skin.gameType.manicIdentifierString ?? String(describing: skin.gameType)),
                          systemImage: "gamecontroller")
                        .lineLimit(1)

                    Spacer()

                    DeviceIndicators(skin: skin)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            ZStack {
                // Base rubber texture
                backgroundColor

                // Noise texture overlay for rubber effect
                Color.black
                    .opacity(0.05)
                    .blendMode(.overlay)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            // Embossed edge effect
            RoundedRectangle(cornerRadius: 16)
                .stroke(innerShadowColor, lineWidth: 2)
                .blur(radius: 2)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lineWidth: 2)
                )
                .blendMode(.overlay)
        }
        .overlay {
            // Inner shadow for depth
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(embossHighlightColor, lineWidth: 1)
                .blur(radius: 1)
                .opacity(0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        .padding(2)
    }
}

/// Process-wide thumbnail cache shared between ``SkinPreviewCell`` and
/// ``SkinSelectionPreviewCell`` so the same skin image is never decoded twice.
final class SkinPreviewThumbnailCache: @unchecked Sendable {
    static let shared = SkinPreviewThumbnailCache()

    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.provenance.skinpreview.cache", attributes: .concurrent)

    func thumbnail(forKey key: String) -> UIImage? {
        queue.sync { cache[key] }
    }

    func store(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) { [self] in
            cache[key] = image
            if cache.count > 100 {
                let keysToRemove = Array(cache.keys.prefix(20))
                for k in keysToRemove { cache.removeValue(forKey: k) }
            }
        }
    }
}

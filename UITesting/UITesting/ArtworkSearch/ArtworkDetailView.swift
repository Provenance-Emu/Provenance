import SwiftUI
import PVLookup
import PVLookupTypes
import PVSystems

struct ArtworkDetailView: View {
    let artworks: [ArtworkMetadata]
    let initialIndex: Int
    let onSelect: (ArtworkSelectionData) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var isZoomed = false
    @GestureState private var scale: CGFloat = 1.0
    @State private var previewImages: [URL: Image] = [:]
    let onPageChange: (ArtworkMetadata) -> Void

    init(artworks: [ArtworkMetadata], initialArtwork: ArtworkMetadata, onSelect: @escaping (ArtworkSelectionData) -> Void, onPageChange: @escaping (ArtworkMetadata) -> Void) {
        self.artworks = artworks
        self.initialIndex = artworks.firstIndex(of: initialArtwork) ?? 0
        self.onSelect = onSelect
        _currentPage = State(initialValue: initialIndex)
        self.onPageChange = onPageChange
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)

                // Main Content
                TabView(selection: $currentPage) {
                    ForEach(Array(artworks.enumerated()), id: \.offset) { index, artwork in
                        ZoomableImageView(
                            artwork: artwork,
                            previewImage: previewImages[artwork.url],
                            geometry: geometry
                        )
                        .tag(index)
                    }
                }
                .onChange(of: currentPage) { page in
                    if let artwork = artworks[safe: page] {
                        onPageChange(artwork)
                    }
                }
                .tabViewStyle(.page)

                // Overlay Controls
                VStack {
                    // Top Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()

                    Spacer()

                    // Bottom Info & Controls
                    VStack(spacing: 10) {
                        // Metadata
                        if let currentArtwork = artworks[safe: currentPage] {
                            VStack(alignment: .leading, spacing: 4) {
                                if let description = currentArtwork.description {
                                    Text(description)
                                        .font(.headline)
                                }
                                Text("\(currentArtwork.type.displayName) • \(currentArtwork.source)")
                                    .font(.subheadline)
                                if let resolution = currentArtwork.resolution {
                                    Text(resolution)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal)

                            // Select Button
                            Button {
                                if let image = previewImages[currentArtwork.url] {
                                    onSelect(ArtworkSelectionData(
                                        metadata: currentArtwork,
                                        previewImage: image
                                    ))
                                    dismiss()
                                }
                            } label: {
                                Text("Select This Artwork")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding()
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .task {
            // Load all images
            for artwork in artworks {
                await loadImage(for: artwork)
            }
        }
    }

    private func loadImage(for artwork: ArtworkMetadata) async {
        guard previewImages[artwork.url] == nil else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: artwork.url)
            if let uiImage = UIImage(data: data) {
                previewImages[artwork.url] = Image(uiImage: uiImage)
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
}

struct ZoomableImageView: View {
    let artwork: ArtworkMetadata
    let previewImage: Image?
    let geometry: GeometryProxy

    @State private var scale = 1.0
    @State private var lastScale = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    var body: some View {
        Group {
            if let image = previewImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            // Pinch to zoom
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                },
                            // Drag when zoomed
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    // Double tap to reset zoom
                    .onTapGesture(count: 2) {
                        withAnimation {
                            scale = scale > 1 ? 1 : 2
                            if scale == 1 {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
}

// Helper extension for safe array access
extension Collection {
    subscript(safe index: Index) -> Self.Element? {
        indices.contains(index) ? self[index] : nil
    }
}

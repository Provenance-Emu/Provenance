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
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false

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
                Color.black
                    .edgesIgnoringSafeArea(.all)
                    .opacity(1 - (abs(dragOffset.height) / 500.0))

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
                        preloadAdjacentImages()
                    }
                }
                .tabViewStyle(.page)

                // Overlay Controls
                overlayControls
                    .opacity(1 - (abs(dragOffset.height) / 300.0))
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isZoomed else { return }
                        dragOffset = value.translation
                        isDragging = true
                    }
                    .onEnded { value in
                        isDragging = false
                        if abs(dragOffset.height) > 100 {
                            dismiss()
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .offset(y: dragOffset.height)
            .animation(.interactiveSpring(), value: isDragging)
        }
        .task {
            await loadInitialImages()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 0 {
                        withAnimation {
                            currentPage = max(0, currentPage - 1)
                        }
                    } else {
                        withAnimation {
                            currentPage = min(artworks.count - 1, currentPage + 1)
                        }
                    }
                }
        )
        .onAppear {
            #if os(macOS)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 123: // Left arrow
                    withAnimation {
                        currentPage = max(0, currentPage - 1)
                    }
                    return nil
                case 124: // Right arrow
                    withAnimation {
                        currentPage = min(artworks.count - 1, currentPage + 1)
                    }
                    return nil
                case 53: // Escape
                    dismiss()
                    return nil
                default:
                    return event
                }
            }
            #endif
        }
    }

    private var overlayControls: some View {
        VStack {
            // Top Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                Spacer()

                Text("\(currentPage + 1) of \(artworks.count)")
                    .foregroundColor(.white)
                    .font(.caption)

                Spacer()

                if let currentArtwork = artworks[safe: currentPage],
                   let image = previewImages[currentArtwork.url] {
                    Button {
                        onSelect(ArtworkSelectionData(
                            metadata: currentArtwork,
                            previewImage: image
                        ))
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(LinearGradient(colors: [.black.opacity(0.7), .clear],
                                     startPoint: .top,
                                     endPoint: .bottom))

            Spacer()

            // Bottom Info
            if let currentArtwork = artworks[safe: currentPage] {
                VStack(spacing: 10) {
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
                }
                .padding(.bottom, 40)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.7)],
                                         startPoint: .top,
                                         endPoint: .bottom))
            }
        }
    }

    private func loadInitialImages() async {
        // Load current image and adjacent images
        let indicesToLoad = [
            max(0, currentPage - 1),
            currentPage,
            min(artworks.count - 1, currentPage + 1)
        ]

        for index in indicesToLoad {
            if let artwork = artworks[safe: index] {
                await loadImage(for: artwork)
            }
        }
    }

    private func preloadAdjacentImages() {
        let adjacentIndices = [
            max(0, currentPage - 1),
            min(artworks.count - 1, currentPage + 1)
        ]

        for index in adjacentIndices {
            let artwork = artworks[index]
            if previewImages[artwork.url] == nil {
                Task {
                    await loadImage(for: artwork)
                }
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
    @State private var loadingError: Error?
    @State private var isLoading = true

    private var isZoomed: Bool {
        scale > 1.0
    }

    var body: some View {
        ZStack {
            if let error = loadingError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let image = previewImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard isZoomed else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .highPriorityGesture(
                        TapGesture(count: 2).onEnded {
                            withAnimation(.spring()) {
                                if isZoomed {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                    )

                // Zoom indicator and reset button
                if isZoomed {
                    VStack {
                        Text("\(Int(scale * 100))%")
                            .font(.caption)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)

                        Button {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        } label: {
                            Text("Reset Zoom")
                                .font(.caption)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }
                    }
                    .transition(.opacity)
                    .padding()
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

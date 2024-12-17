import SwiftUI
import PVLookup
import PVLookupTypes
import PVSystems
import TheGamesDB

struct ArtworkSearchView: View {
    @State private var searchText = ""
    @State private var selectedSystem: SystemIdentifier?
    @State private var searchMode: ArtworkSearchMode = .both
    @State private var artworkResults: [ArtworkMetadata] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSelect: (ArtworkSelectionData) -> Void

    var body: some View {
        VStack {
            // Search controls
            searchControls

            // Results grid
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                artworkGrid
            }
        }
        .padding()
    }

    private var searchControls: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search artwork...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await performSearch()
                        }
                    }
            }

            // System selector
            HStack {
                Text("System:")
                Picker("System", selection: $selectedSystem) {
                    Text("Any").tag(nil as SystemIdentifier?)
                    ForEach(SystemIdentifier.allCases.sorted { $0.rawValue < $1.rawValue }, id: \.self) { system in
                        Text(system.rawValue)
                            .tag(Optional(system))
                    }
                }
            }

            // Search mode selector
            Picker("Search Mode", selection: $searchMode) {
                Text("Offline").tag(ArtworkSearchMode.offline)
                Text("Online").tag(ArtworkSearchMode.online)
                Text("Both").tag(ArtworkSearchMode.both)
            }
            .pickerStyle(.segmented)
        }
    }

    private var artworkGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150, maximum: 200))
            ], spacing: 20) {
                ForEach(artworkResults, id: \.url) { artwork in
                    ArtworkGridItem(artwork: artwork) { selectionData in
                        onSelect(selectionData)
                    }
                }
            }
            .padding()
        }
    }

    private func performSearch() async {
        isLoading = true
        errorMessage = nil
        artworkResults.removeAll()

        // TODO: Implement actual search using PVLookup
        // This is just a placeholder
        do {
            // Example implementation:
            let service = TheGamesDBService()
            if let results = try await service.searchArtwork(
                byGameName: searchText,
                systemID: selectedSystem,
                artworkTypes: [.boxFront, .screenshot]
            ) {
                artworkResults = results
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// Grid item view
struct ArtworkGridItem: View {
    let artwork: ArtworkMetadata
    let onSelect: (ArtworkSelectionData) -> Void

    @State private var image: Image?
    @State private var isLoading = true

    var body: some View {
        VStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
            } else if isLoading {
                ProgressView()
                    .frame(height: 150)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .foregroundColor(.gray)
            }

            Text(artwork.type.rawValue)
                .font(.caption)

            if let resolution = artwork.resolution {
                Text(resolution)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
        .onTapGesture {
            onSelect(ArtworkSelectionData(metadata: artwork, previewImage: image))
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }

        // TODO: Implement actual image loading
        // This is just a placeholder
        do {
            let (data, _) = try await URLSession.shared.data(from: artwork.url)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
}

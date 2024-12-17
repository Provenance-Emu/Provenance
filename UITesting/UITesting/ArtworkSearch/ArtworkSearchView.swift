import SwiftUI
import PVLookup
import PVLookupTypes
import PVSystems
import TheGamesDB

struct ArtworkSearchView: View {
    @State private var searchText = ""
    @State private var selectedSystem: SystemIdentifier?
    @State private var artworkResults: [ArtworkMetadata] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.sampleArtworkResults) private var sampleResults
    @State private var collapsedGroups: Set<String> = Set()
    @State private var selectedTypes: ArtworkType = .defaults

    let onSelect: (ArtworkSelectionData) -> Void

    // Use sample results in preview
    private var displayResults: [ArtworkMetadata] {
        #if DEBUG
        return !sampleResults.isEmpty ? sampleResults : artworkResults
        #else
        return artworkResults
        #endif
    }

    // Group results by source domain
    private var groupedResults: [(String, [ArtworkMetadata])] {
        Dictionary(grouping: displayResults) { artwork in
            artwork.url.host ?? "Unknown Source"
        }
        .sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search controls - always at top
            searchControls
                .padding()

            // Results area with fixed spacing
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                    Spacer()
                } else {
                    artworkGrid
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var searchControls: some View {
        VStack(spacing: 12) {
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
                    ForEach(SystemIdentifier.allCases.filter{!$0.libretroDatabaseName.isEmpty}.sorted {
                        $0.libretroDatabaseName < $1.libretroDatabaseName
                    }, id: \.self) { system in
                        Text(system.libretroDatabaseName)
                            .tag(Optional(system))
                    }
                }
                Spacer()
            }

            // New artwork type selector
            ArtworkTypeSelector(selectedTypes: $selectedTypes)
        }
        .padding()
    }

    private var artworkGrid: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(groupedResults, id: \.0) { source, artworks in
                    VStack(alignment: .leading, spacing: 8) {
                        // Collapsible header
                        Button {
                            withAnimation {
                                if collapsedGroups.contains(source) {
                                    collapsedGroups.remove(source)
                                } else {
                                    collapsedGroups.insert(source)
                                }
                            }
                        } label: {
                            HStack {
                                Text(source)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: collapsedGroups.contains(source) ? "chevron.right" : "chevron.down")
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        // Collapsible content - show if NOT collapsed
                        if !collapsedGroups.contains(source) {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 150, maximum: 200))
                            ], spacing: 20) {
                                ForEach(artworks, id: \.url) { artwork in
                                    ArtworkGridItem(
                                        artwork: artwork,
                                        onSelect: onSelect,
                                        showSystem: selectedSystem == nil
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    Divider()
                }
            }
            .padding(.vertical)
        }
    }

    private func performSearch() async {
        isLoading = true
        errorMessage = nil
        artworkResults.removeAll()

        do {
            // Use PVLookup.shared instead of TheGamesDBService directly
            if let results = try await PVLookup.shared.searchArtwork(
                byGameName: searchText,
                systemID: selectedSystem,
                artworkTypes: selectedTypes
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
    let showSystem: Bool

    @State private var image: Image?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 4) {
            // Image section
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

            // Metadata section
            VStack(alignment: .leading, spacing: 2) {
                if let gameName = artwork.description {
                    Text(gameName)
                        .font(.caption)
                        .lineLimit(1)
                }

                HStack {
                    Text(artwork.type.displayName)
                        .font(.caption)

                    if showSystem, let system = artwork.systemID?.libretroDatabaseName {
                        Text("•")
                            .font(.caption)
                        Text(system)
                            .font(.caption)
                    }
                }

                if let resolution = artwork.resolution {
                    Text(resolution)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

// Add this new view for artwork type selection
struct ArtworkTypeSelector: View {
    @Binding var selectedTypes: ArtworkType

    private let allTypes: [ArtworkType] = [
        .boxFront, .boxBack, .screenshot, .titleScreen,
        .clearLogo, .banner, .fanArt, .manual
    ]

    // Helper to count selected types
    private var selectedCount: Int {
        allTypes.filter { selectedTypes.contains($0) }.count
    }

    var body: some View {
        Menu {
            ForEach(allTypes, id: \.rawValue) { type in
                Button {
                    if selectedTypes.contains(type) {
                        selectedTypes.remove(type)
                    } else {
                        selectedTypes.insert(type)
                    }
                } label: {
                    HStack {
                        Text(type.displayName)
                        if selectedTypes.contains(type) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button("Select All") {
                selectedTypes = ArtworkType(allTypes)
            }

            Button("Clear All") {
                selectedTypes = []
            }

            Button("Reset to Defaults") {
                selectedTypes = .defaults
            }
        } label: {
            HStack {
                Text("Artwork Types")
                Image(systemName: "chevron.up.chevron.down")
                Spacer()
                // Show count of selected types using our helper
                if selectedCount > 0 {
                    Text("\(selectedCount) selected")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#if DEBUG
// Environment key for sample data
private struct SampleArtworkResultsKey: EnvironmentKey {
    static let defaultValue: [ArtworkMetadata] = []
}

extension EnvironmentValues {
    var sampleArtworkResults: [ArtworkMetadata] {
        get { self[SampleArtworkResultsKey.self] }
        set { self[SampleArtworkResultsKey.self] = newValue }
    }
}

#Preview("Artwork Search") {
    NavigationView {
        ArtworkSearchView { selection in
            print("Preview selected artwork: \(selection.metadata.url)")
        }
        .navigationTitle("Artwork Search")
    }
}

#Preview("Artwork Search - With Results") {
    NavigationView {
        ArtworkSearchView { selection in
            print("Preview selected artwork: \(selection.metadata.url)")
        }
        .navigationTitle("Artwork Search")
    }
    .environment(\.sampleArtworkResults, [
        ArtworkMetadata(
            url: URL(string: "https://cdn.thegamesdb.net/images/original/boxart/front/136-1.jpg")!,
            type: .boxFront,
            resolution: "2100x1500",
            description: nil,
            source: "TheGamesDB"
        ),
        ArtworkMetadata(
            url: URL(string: "https://cdn.thegamesdb.net/images/original/screenshot/136-1.jpg")!,
            type: .screenshot,
            resolution: "1920x1080",
            description: nil,
            source: "TheGamesDB"
        ),
        ArtworkMetadata(
            url: URL(string: "https://retrodb.net/images/boxart/snes/super-mario-world.jpg")!,
            type: .boxFront,
            resolution: "800x600",
            description: nil,
            source: "LibretroDB"
        )
    ])
}
#endif

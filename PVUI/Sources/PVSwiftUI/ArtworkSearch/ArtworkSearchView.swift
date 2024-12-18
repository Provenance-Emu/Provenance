import SwiftUI
import PVLookup
import PVLookupTypes
import PVSystems
import TheGamesDB

public struct ArtworkSearchView: View {
    @State private var searchText: String = ""
    @State private var selectedSystem: SystemIdentifier?
    @State private var artworkResults: [ArtworkMetadata] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @Environment(\.sampleArtworkResults) private var sampleResults
    @State private var collapsedGroups: Set<String> = Set()
    @State private var selectedTypes: ArtworkType = .defaults
    @State private var lastViewedArtwork: ArtworkMetadata?
    @State private var loadingStates: [URL: LoadingState] = [:]
    @State private var searchHistory: [String] = UserDefaults.standard.stringArray(forKey: "artworkSearchHistory") ?? []
    @State private var previewImages: [URL: Image] = [:]

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

    /// Creates a new ArtworkSearchView
    /// - Parameters:
    ///   - initialSearch: Optional initial search term to populate the search field
    ///   - initialSystem: Optional system to pre-filter the results
    ///   - onSelect: Callback when an artwork is selected
    public init(
        initialSearch: String = "",
        initialSystem: SystemIdentifier? = nil,
        onSelect: @escaping (ArtworkSelectionData) -> Void
    ) {
        self._searchText = State(initialValue: initialSearch)
        self._selectedSystem = State(initialValue: initialSystem)
        self.onSelect = onSelect
    }

    public var body: some View {
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
                } else if hasSearched && displayResults.isEmpty {
                    Spacer()
                    NoResultsView(searchText: searchText)
                    Spacer()
                } else if !hasSearched {
                    Spacer()
                    Text("Search for artwork above")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            // Search bar with button
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search artwork...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            addToHistory(searchText)
                            await performSearch()
                        }
                    }

                // Recent searches menu
                Menu {
                    ForEach(searchHistory, id: \.self) { term in
                        Button(term) {
                            searchText = term
                            Task {
                                await performSearch()
                            }
                        }
                    }
                    if !searchHistory.isEmpty {
                        Divider()
                        Button("Clear History", role: .destructive) {
                            searchHistory.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .disabled(searchHistory.isEmpty)

                Button {
                    Task {
                        addToHistory(searchText)
                        await performSearch()
                    }
                } label: {
                    Text("Search")
                }
                .disabled(searchText.isEmpty)
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
            .onChange(of: selectedSystem) { _ in
                if !searchText.isEmpty {
                    Task {
                        await performSearch()
                    }
                }
            }

            // Artwork type selector
            ArtworkTypeSelector(selectedTypes: $selectedTypes)
                .onChange(of: selectedTypes) { _ in
                    if !searchText.isEmpty {
                        Task {
                            await performSearch()
                        }
                    }
                }
        }
        .padding()
    }

    private var artworkGrid: some View {
        ScrollViewReader { proxy in
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
                                        artworkGridItem(artwork)
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
                .onChange(of: lastViewedArtwork) { artwork in
                    if let artwork = artwork {
                        withAnimation {
                            proxy.scrollTo(artwork.url, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func performSearch() async {
        isLoading = true
        errorMessage = nil
        artworkResults.removeAll()
        hasSearched = true

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

    enum LoadingState {
        case loading
        case loaded
        case error(Error)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }

        var error: Error? {
            if case .error(let error) = self { return error }
            return nil
        }
    }

    private func loadArtwork(from url: URL) async {
        loadingStates[url] = .loading
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    previewImages[url] = Image(uiImage: uiImage)
                    loadingStates[url] = .loaded
                }
            }
        } catch {
            await MainActor.run {
                loadingStates[url] = .error(error)
                DLOG("Failed to load artwork: \(error.localizedDescription)")
            }
        }
    }

    private func addToHistory(_ search: String) {
        guard !search.isEmpty,
              !searchHistory.contains(search) else { return }

        var newHistory = searchHistory
        newHistory.insert(search, at: 0)
        if newHistory.count > 10 {
            newHistory.removeLast()
        }

        searchHistory = newHistory
        UserDefaults.standard.set(newHistory, forKey: "artworkSearchHistory")
    }

    private func artworkGridItem(_ artwork: ArtworkMetadata) -> some View {
        VStack {
            Group {
                if let loadingState = loadingStates[artwork.url] {
                    switch loadingState {
                    case .loading:
                        ProgressView()
                    case .loaded:
                        if let image = previewImages[artwork.url] {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    case .error(let error):
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    Color.clear
                        .onAppear {
                            Task {
                                await loadArtwork(from: artwork.url)
                            }
                        }
                }
            }
            .frame(height: 150)
            .onTapGesture {
                lastViewedArtwork = artwork
                onSelect(ArtworkSelectionData(metadata: artwork, previewImage: previewImages[artwork.url]))
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

                    if let system = artwork.systemID?.libretroDatabaseName {
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
    }
}

// Grid item view
struct ArtworkGridItem: View {
    let artwork: ArtworkMetadata
    let allArtworks: [ArtworkMetadata]
    let onSelect: (ArtworkSelectionData) -> Void
    let showSystem: Bool
    let onArtworkViewed: (ArtworkMetadata) -> Void

    @State private var image: Image?
    @State private var isLoading = true
    @State private var showDetail = false
    @State private var shouldScrollOnDismiss = false

    var body: some View {
        VStack(spacing: 4) {
            // Image section
            Group {
                if let image = image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 150)
            .onTapGesture {
                showDetail = true
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
        .fullScreenCover(isPresented: $showDetail) {
            if shouldScrollOnDismiss {
                onArtworkViewed(artwork)
            }
            shouldScrollOnDismiss = false
        } content: {
            ArtworkDetailView(
                artworks: allArtworks,
                initialArtwork: artwork,
                onSelect: onSelect,
                onPageChange: { artwork in
                    shouldScrollOnDismiss = true
                }
            )
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

struct NoResultsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No artwork found")
                .font(.headline)
                .foregroundColor(.primary)

            if !searchText.isEmpty {
                Text("No results found for \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Try adjusting your search or artwork type filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
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

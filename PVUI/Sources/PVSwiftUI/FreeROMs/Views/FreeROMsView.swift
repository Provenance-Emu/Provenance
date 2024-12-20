import SwiftUI
import PVSystems

/// View for displaying and downloading free ROMs
public struct FreeROMsView: View {
    /// Callback when a ROM is downloaded
    let onROMDownloaded: (ROM, URL) -> Void
    /// Optional callback when view is dismissed
    let onDismiss: (() -> Void)?

    @StateObject private var downloadManager = ROMDownloadManager()
    @State private var searchText = ""
    @State private var expandedSystems: Set<String> = Set()
    @State private var systems: [(id: String, name: String, roms: [ROM])] = []
    @State private var loadingError: Error?
    @State private var isLoading = false

    public init(
        onROMDownloaded: @escaping (ROM, URL) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.onROMDownloaded = onROMDownloaded
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationView {
            Group {
                if let error = loadingError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)

                        Text("Failed to Load ROMs")
                            .font(.headline)

                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Retry") {
                            loadROMs()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if isLoading {
                    ProgressView("Loading ROMs...")
                } else if !systems.isEmpty {
                    List {
                        ForEach(systems, id: \.id) { system in
                            Section {
                                if expandedSystems.contains(system.id) {
                                    ForEach(filteredROMs(system.roms)) { rom in
                                        ROMRowView(rom: rom,
                                                 systemId: system.id,
                                                 downloadManager: downloadManager,
                                                 onDownloaded: onROMDownloaded)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(system.name)
                                    Spacer()
                                    Text("\(system.roms.count) ROMs")
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Haptics.impact(style: .rigid)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if expandedSystems.contains(system.id) {
                                            expandedSystems.remove(system.id)
                                        } else {
                                            expandedSystems.insert(system.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
                        ContentUnavailableView("No ROMs Found",
                                             systemImage: "gamecontroller.fill",
                                             description: Text("Try checking your internet connection and retry."))
                    } else {
                        Text("No ROMs Found")
                    }
                }
            }
            .navigationTitle("Free ROMs")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if expandedSystems.count == systems.count {
                                expandedSystems.removeAll()
                            } else {
                                expandedSystems = Set(systems.map(\.id))
                            }
                        }
                    } label: {
                        Label(
                            expandedSystems.count == systems.count ? "Collapse All" : "Expand All",
                            systemImage: expandedSystems.count == systems.count ? "chevron.up" : "chevron.down"
                        )
                    }
                }
            }
        }
        .onAppear {
            if systems.isEmpty && loadingError == nil {
                loadROMs()
            }
        }
        .onDisappear {
            onDismiss?()
        }
    }

    private func filteredROMs(_ roms: [ROM]) -> [ROM] {
        if searchText.isEmpty {
            return roms
        }
        return roms.filter { $0.file.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadROMs() {
        guard let url = URL(string: "https://data.provenance-emu.com/roms_mapping.json") else {
            loadingError = NSError(domain: "FreeROMs",
                                 code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            return
        }

        isLoading = true
        loadingError = nil

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    loadingError = error
                    return
                }

                guard let data = data else {
                    loadingError = NSError(domain: "FreeROMs",
                                         code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    return
                }

                do {
                    let mapping = try JSONDecoder().decode(ROMMapping.self, from: data)
                    // Transform the mapping into our simpler array structure
                    self.systems = mapping.systems.compactMap { key, value in
                        if let systemIdentifier = SystemIdentifier(rawValue: key) {
                            return (id: key,
                                   name: systemIdentifier.libretroDatabaseName,
                                   roms: value.roms)
                        }
                        return nil
                    }.sorted { $0.name < $1.name }

                    // Expand all sections by default
                    self.expandedSystems = Set(self.systems.map(\.id))
                } catch {
                    loadingError = error
                }
            }
        }.resume()
    }
}

/// Individual ROM row view
struct ROMRowView: View {
    let rom: ROM
    let systemId: String
    @ObservedObject var downloadManager: ROMDownloadManager
    let onDownloaded: (ROM, URL) -> Void

    @State private var selectedArtwork: URL?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(rom.file)
                    .font(.headline)
                    .lineLimit(1)

                Text(ByteCountFormatter.string(fromByteCount: Int64(rom.size), countStyle: .file))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let artwork = rom.artwork {
                HStack(spacing: 8) {
                    if let coverPath = artwork.cover,
                       let coverURL = URL(string: "https://data.provenance-emu.com/ROMs/\(systemId)/\(coverPath)") {
                        ArtworkThumbnail(url: coverURL) {
                            Haptics.impact(style: .light)
                            selectedArtwork = coverURL
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    if let screenshotPath = artwork.screenshot,
                       let screenshotURL = URL(string: "https://data.provenance-emu.com/ROMs/\(systemId)/\(screenshotPath)") {
                        ArtworkThumbnail(url: screenshotURL) {
                            Haptics.impact(style: .light)
                            selectedArtwork = screenshotURL
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.trailing, 12)
                .shadow(radius: 1)
            }

            DownloadButton(rom: rom,
                          systemId: systemId,
                          downloadManager: downloadManager,
                          onDownloaded: onDownloaded)
        }
        .padding(.vertical, 4)
        .fullScreenCover(item: $selectedArtwork) { url in
            ArtworkFullscreenView(imageURL: url)
        }
        .shadow(radius: 1)
    }
}

// Make URL conform to Identifiable for fullScreenCover
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Download button with progress indicator
struct DownloadButton: View {
    let rom: ROM
    let systemId: String
    @ObservedObject var downloadManager: ROMDownloadManager
    let onDownloaded: (ROM, URL) -> Void

    var body: some View {
        Group {
            if let status = downloadManager.activeDownloads[rom.id] {
                switch status {
                case .downloading(let progress):
                    VStack(spacing: 2) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .overlay {
                                Circle()
                                    .stroke(Color.secondary, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                case .completed(let localURL):
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 22))
                        .onAppear {
                            onDownloaded(rom, localURL)
                        }
                case .failed(let error):
                    DownloadErrorView(error: error) {
                        Haptics.notification(type: .warning)
                        startDownload()
                    }
                }
            } else {
                Button(action: startDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 22))
                }
            }
        }
    }

    private func startDownload() {
        guard let url = URL(string: "https://data.provenance-emu.com/ROMs/\(systemId)/\(rom.file)") else {
            downloadManager.setError(.invalidURL, for: rom.id)
            return
        }
        Haptics.notification(type: .success)
        downloadManager.download(rom: rom, from: url) { _ in }
    }
}

private enum Haptics {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}


#if DEBUG
// MARK: - Preview
struct FreeROMsView_Previews: PreviewProvider {
    static var previews: some View {
        FreeROMsView { rom, url in
            print("Downloaded \(rom.file) to \(url)")
        }
    }
}
#endif

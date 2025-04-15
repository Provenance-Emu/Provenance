import SwiftUI
import PVSystems

/// View for displaying and downloading free ROMs
public struct FreeROMsView: View {
    /// Systems to exclude from the list
    private static let unsupportedSystems: Set<SystemIdentifier> = [
        //        ._3DS,        // Not supported yet
        .Dreamcast,
        .MAME,
        .PS2,         // Not supported yet
        .PS3,         // Not supported yet
        .Wii,         // Not supported yet
        .GameCube,    // Not supported yet
        //        .DOS,         // Not supported yet
            .Macintosh,   // Not supported yet
        .PalmOS,      // Not supported yet
        .Music,        // Not a gaming system
        .TIC80,
        .Vectrex
    ]
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0
    @State private var selectedSystemId: String? = nil
    
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
    
    private var filteredSystems: [(id: String, name: String, roms: [ROM])] {
        systems.filter { system in
            guard let systemIdentifier = SystemIdentifier(rawValue: system.id) else {
                return false
            }
            return !Self.unsupportedSystems.contains(systemIdentifier)
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // RetroWave background
                RetroTheme.retroBackground
                
                // Grid overlay
                RetroGrid()
                    .opacity(0.3)
                
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
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: RetroTheme.retroPink))
                                .scaleEffect(1.5)
                            
                            Text("LOADING ROMS...")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(RetroTheme.retroPink)
                                .padding(.top, 16)
                                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                        }
                    } else if !systems.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredSystems, id: \.id) { system in
                                    VStack(spacing: 0) {
                                        if expandedSystems.contains(system.id) {
                                            ForEach(filteredROMs(system.roms)) { rom in
                                                ROMRowView(rom: rom,
                                                           systemId: system.id,
                                                           downloadManager: downloadManager,
                                                           onDownloaded: onROMDownloaded)
                                            }
                                        }
                                        // System header with retrowave styling
                                        Button(action: {
#if !os(tvOS)
                                            Haptics.impact(style: .rigid)
#endif
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                if expandedSystems.contains(system.id) {
                                                    expandedSystems.remove(system.id)
                                                } else {
                                                    expandedSystems.insert(system.id)
                                                }
                                            }
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(system.name)
                                                        .font(.system(size: 18, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                                                    
                                                    Text("\(system.roms.count) ROMs")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(RetroTheme.retroPurple)
                                                        .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                                                }
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 12) {
                                                    Button {
                                                        downloadAllROMs(for: system)
                                                    } label: {
                                                        Image(systemName: "arrow.down.circle.fill")
                                                            .foregroundColor(RetroTheme.retroPink)
                                                            .font(.system(size: 22))
                                                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                                                    }
                                                    
                                                    Image(systemName: expandedSystems.contains(system.id) ? "chevron.up" : "chevron.down")
                                                        .foregroundColor(RetroTheme.retroBlue)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.black.opacity(0.7))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .strokeBorder(
                                                                LinearGradient(
                                                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                                                    startPoint: .leading,
                                                                    endPoint: .trailing
                                                                ),
                                                                lineWidth: selectedSystemId == system.id ? 2.0 : 1.0
                                                            )
                                                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity),
                                                                    radius: selectedSystemId == system.id ? 5 : 2,
                                                                    x: 0,
                                                                    y: 0)
                                                    )
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
#if os(tvOS)
                                        .focusable(true)
//                                        .onFocusChange { focused in
//                                            if focused {
//                                                selectedSystemId = system.id
//                                            }
//                                        }
#endif
                                        
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 50))
                                .foregroundColor(RetroTheme.retroPink)
                                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)
                            
                            Text("NO ROMS FOUND")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(RetroTheme.retroBlue)
                                .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                            
                            Text("Try checking your internet connection and retry.")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button(action: {
                                loadROMs()
                            }) {
                                Text("RETRY")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(RetroTheme.retroPurple)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(LinearGradient(
                                                gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroPink]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ), lineWidth: 1.5)
                                    )
                                    .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                            }
#if os(tvOS)
                            .focusable(true)
#endif
                        }
                    }
                }
            }
            .navigationTitle("FREE ROMS")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "SEARCH ROMS")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if expandedSystems.count == filteredSystems.count {
                                expandedSystems.removeAll()
                            } else {
                                expandedSystems = Set(filteredSystems.map(\.id))
                            }
                        }
                    } label: {
                        HStack {
                            Text(expandedSystems.count == filteredSystems.count ? "COLLAPSE ALL" : "EXPAND ALL")
                                .font(.system(size: 14, weight: .bold))
                            
                            Image(systemName: expandedSystems.count == filteredSystems.count ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(RetroTheme.retroBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ), lineWidth: 1.5)
                        )
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                    }
#if os(tvOS)
                    .focusable(true)
#endif
                }
            }
            .onAppear {
                if systems.isEmpty && loadingError == nil {
                    loadROMs()
                }
                
                // Start retrowave animations
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
            .onDisappear {
                onDismiss?()
            }
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
                    // Transform the mapping into our simpler array structure without filtering
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
    
    private func downloadAllROMs(for system: (id: String, name: String, roms: [ROM])) {
#if !os(tvOS)
        Haptics.notification(type: .success)
#endif
        // Queue all ROMs for download
        for rom in system.roms {
            guard let url = URL(string: "https://data.provenance-emu.com/ROMs/\(system.id)/\(rom.file)") else {
                downloadManager.setError(.invalidURL, for: rom.id)
                continue
            }
            
            downloadManager.download(rom: rom, from: url) { _ in }
        }
    }
}

/// Individual ROM row view
struct ROMRowView: View {
    let rom: ROM
    let systemId: String
    @ObservedObject var downloadManager: ROMDownloadManager
    let onDownloaded: (ROM, URL) -> Void
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false
    
    @State private var selectedArtwork: URL?
    
    var body: some View {
        ZStack {
            // Background with retrowave styling
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 2.0 : 1.5
                        )
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: isHovered ? 5 : 3, x: 0, y: 0)
                )
            
            // Content
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rom.file)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                        .lineLimit(1)
                    
                    Text(ByteCountFormatter.string(fromByteCount: Int64(rom.size), countStyle: .file))
                        .font(.system(size: 14))
                        .foregroundColor(RetroTheme.retroPurple)
                        .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                }
                .padding(.leading, 4)
                
                Spacer()
                
                if let artwork = rom.artwork {
                    HStack(spacing: 10) {
                        if let coverPath = artwork.cover,
                           let coverURL = URL(string: "https://data.provenance-emu.com/ROMs/\(systemId)/\(coverPath)") {
                            ArtworkThumbnail(url: coverURL) {
#if !os(tvOS)
                                Haptics.impact(style: .light)
#endif
                                selectedArtwork = coverURL
                            }
                            .transition(.scale.combined(with: .opacity))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(RetroTheme.retroBlue, lineWidth: 1)
                                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                            )
                        }
                        
                        if let screenshotPath = artwork.screenshot,
                           let screenshotURL = URL(string: "https://data.provenance-emu.com/ROMs/\(systemId)/\(screenshotPath)") {
                            ArtworkThumbnail(url: screenshotURL) {
#if !os(tvOS)
                                Haptics.impact(style: .light)
#endif
                                selectedArtwork = screenshotURL
                            }
                            .transition(.scale.combined(with: .opacity))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(RetroTheme.retroBlue, lineWidth: 1)
                                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                            )
                        }
                    }
                    .padding(.trailing, 12)
                }
                
                DownloadButton(rom: rom,
                               systemId: systemId,
                               downloadManager: downloadManager,
                               onDownloaded: onDownloaded)
                .padding(.trailing, 8)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .frame(height: 70)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
#if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
#endif
#if os(tvOS)
        .focusable(true)
//        .onFocusChange { focused in
//            withAnimation(.easeInOut(duration: 0.2)) {
//                isHovered = focused
//            }
//        }
#endif
        .onAppear {
            // Start animations
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
        .fullScreenCover(item: $selectedArtwork) { url in
            ArtworkFullscreenView(imageURL: url)
        }
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
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    
    var body: some View {
        Group {
            if let status = downloadManager.activeDownloads[rom.id] {
                switch status {
                case .downloading(let progress):
                    VStack(spacing: 2) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(RetroTheme.retroPink)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 24, height: 24)
                                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                            }
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(RetroTheme.retroPink)
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                    }
                case .completed(let localURL):
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(RetroTheme.retroBlue)
                        .font(.system(size: 24, weight: .bold))
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                        .onAppear {
                            onDownloaded(rom, localURL)
                        }
                case .failed(let error):
                    DownloadErrorView(error: error) {
#if !os(tvOS)
                        Haptics.notification(type: .warning)
#endif
                        startDownload()
                    }
                }
            } else {
                Button(action: startDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(RetroTheme.retroPink)
                        .font(.system(size: 24, weight: .bold))
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
#if os(tvOS)
                .focusable(true)
#endif
            }
        }
    }
    
    private func startDownload() {
        guard let url = URL(string: "https://data.provenance-emu.com/ROMs/\(systemId)/\(rom.file)") else {
            downloadManager.setError(.invalidURL, for: rom.id)
            return
        }
#if !os(tvOS)
        Haptics.notification(type: .success)
#endif
        downloadManager.download(rom: rom, from: url) { _ in }
    }
    
    // Start animations when view appears
    private var animationEffect: some View {
        Color.clear
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
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

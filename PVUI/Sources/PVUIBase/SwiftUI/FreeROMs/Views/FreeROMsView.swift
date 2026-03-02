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

    #if os(tvOS)
    @FocusState private var focusedSystemId: String?
    @FocusState private var isSearchFieldFocused: Bool
    #endif

    /// Platform-adaptive font sizes for 10-foot (tvOS) vs handheld (iOS) UI
    private var systemNameFontSize: CGFloat {
        #if os(tvOS)
        return 28
        #else
        return 18
        #endif
    }

    private var systemRomCountFontSize: CGFloat {
        #if os(tvOS)
        return 20
        #else
        return 14
        #endif
    }

    private var headerVerticalPadding: CGFloat {
        #if os(tvOS)
        return 18
        #else
        return 12
        #endif
    }

    private var headerHorizontalPadding: CGFloat {
        #if os(tvOS)
        return 24
        #else
        return 16
        #endif
    }

    private var downloadAllIconSize: CGFloat {
        #if os(tvOS)
        return 30
        #else
        return 22
        #endif
    }

    private var chevronIconSize: CGFloat {
        #if os(tvOS)
        return 22
        #else
        return 16
        #endif
    }

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
        NavigationStack {
            ZStack {
                RetroTheme.retroBackground
                RetroGrid()
                    .opacity(0.3)

                Group {
                    if let error = loadingError {
                        errorView(error)
                    } else if isLoading {
                        loadingView
                    } else if !systems.isEmpty {
                        systemListView
                    } else {
                        emptyView
                    }
                }
            }
            .navigationTitle("FREE ROMS")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "SEARCH ROMS")
            #endif
            #if os(tvOS)
            .toolbar(.hidden, for: .navigationBar)
            #else
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    expandCollapseButton
                }
            }
            #endif
            .onAppear {
                if systems.isEmpty && loadingError == nil {
                    loadROMs()
                }
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
            .onDisappear {
                onDismiss?()
            }
        }
    }

    // MARK: - Subviews

    private func errorView(_ error: Error) -> some View {
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
    }

    private var loadingView: some View {
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
    }

    private var systemListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                #if os(tvOS)
                tvHeaderBar
                tvSearchField
                #endif
                ForEach(filteredSystems, id: \.id) { system in
                    VStack(spacing: 0) {
                        systemHeaderButton(for: system)
                        if expandedSystems.contains(system.id) {
                            ForEach(filteredROMs(system.roms)) { rom in
                                ROMRowView(rom: rom,
                                           systemId: system.id,
                                           downloadManager: downloadManager,
                                           onDownloaded: onROMDownloaded)
                            }
                        }
                    }
                }
            }
        }
        #if os(tvOS)
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        #else
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        #endif
    }

    #if os(tvOS)
    /// Themed header bar for tvOS with close, title, and expand/collapse
    private var tvHeaderBar: some View {
        HStack(spacing: 20) {
            tvThemedButton(
                title: "Close",
                icon: "xmark.circle.fill",
                accentColor: RetroTheme.retroPink
            ) {
                onDismiss?()
            }

            Spacer()

            Text("FREE ROMS")
                .font(.system(size: 38, weight: .black))
                .foregroundColor(RetroTheme.retroBlue)
                .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 6)

            Spacer()

            tvThemedButton(
                title: expandedSystems.count == filteredSystems.count ? "Collapse All" : "Expand All",
                icon: expandedSystems.count == filteredSystems.count ? "chevron.up" : "chevron.down",
                accentColor: RetroTheme.retroBlue
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if expandedSystems.count == filteredSystems.count {
                        expandedSystems.removeAll()
                    } else {
                        expandedSystems = Set(filteredSystems.map(\.id))
                    }
                }
            }
        }
    }

    /// Reusable retrowave-styled button for tvOS toolbar replacements
    private func tvThemedButton(title: String, icon: String, accentColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                Text(title)
                    .font(.system(size: 22, weight: .bold))
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [accentColor, accentColor.opacity(0.5)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: accentColor.opacity(glowOpacity * 0.5), radius: 3)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
    }

    /// Inline search field for tvOS
    private var tvSearchField: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(isSearchFieldFocused ? RetroTheme.retroBlue : RetroTheme.retroPurple)
                .shadow(color: (isSearchFieldFocused ? RetroTheme.retroBlue : RetroTheme.retroPurple).opacity(glowOpacity), radius: 4)

            TextField("SEARCH ROMS", text: $searchText)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
                .focused($isSearchFieldFocused)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(RetroTheme.retroPink)
                }
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: isSearchFieldFocused ? 2.5 : 1.0
                        )
                        .shadow(color: RetroTheme.retroBlue.opacity(isSearchFieldFocused ? glowOpacity : 0.3),
                                radius: isSearchFieldFocused ? 8 : 2)
                )
        )
        .scaleEffect(isSearchFieldFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSearchFieldFocused)
    }
    #endif

    /// Shared background for system header cards
    private func systemHeaderBackground(isFocused: Bool, systemId: String) -> some View {
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
                        lineWidth: isFocused ? 3.0 : (selectedSystemId == systemId ? 2.0 : 1.0)
                    )
                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity),
                            radius: isFocused ? 8 : (selectedSystemId == systemId ? 5 : 2),
                            x: 0, y: 0)
            )
    }

    /// System header with retrowave styling and proper tvOS focus support
    @ViewBuilder
    private func systemHeaderButton(for system: (id: String, name: String, roms: [ROM])) -> some View {
        #if os(tvOS)
        tvSystemHeader(for: system)
        #else
        iosSystemHeader(for: system)
        #endif
    }

    #if os(tvOS)
    /// tvOS: separate focusable buttons for expand/collapse and download all
    @FocusState private var focusedHeaderAction: String?

    private func tvSystemHeader(for system: (id: String, name: String, roms: [ROM])) -> some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if expandedSystems.contains(system.id) {
                        expandedSystems.remove(system.id)
                    } else {
                        expandedSystems.insert(system.id)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(system.name)
                            .font(.system(size: systemNameFontSize, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2)

                        Text("\(system.roms.count) ROMs")
                            .font(.system(size: systemRomCountFontSize))
                            .foregroundColor(RetroTheme.retroPurple)
                            .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity * 0.6), radius: 1)
                    }

                    Spacer()

                    Image(systemName: expandedSystems.contains(system.id) ? "chevron.up" : "chevron.down")
                        .foregroundColor(RetroTheme.retroBlue)
                        .font(.system(size: chevronIconSize, weight: .bold))
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2)
                }
                .padding(.vertical, headerVerticalPadding)
                .padding(.horizontal, headerHorizontalPadding)
                .background(systemHeaderBackground(isFocused: focusedSystemId == system.id, systemId: system.id))
            }
            .buttonStyle(TVMediaCardButtonStyle())
            .tvOSDisableFocusEffect()
            .focused($focusedSystemId, equals: system.id)
            .scaleEffect(focusedSystemId == system.id ? 1.03 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedSystemId == system.id)

            Button {
                downloadAllROMs(for: system)
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(RetroTheme.retroPink)
                    .font(.system(size: downloadAllIconSize))
                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 2)
                    .padding(.vertical, headerVerticalPadding)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(RetroTheme.retroPink.opacity(0.6), lineWidth: focusedHeaderAction == "dl-\(system.id)" ? 2.5 : 1.0)
                                    .shadow(color: RetroTheme.retroPink.opacity(focusedHeaderAction == "dl-\(system.id)" ? glowOpacity : 0.2), radius: focusedHeaderAction == "dl-\(system.id)" ? 6 : 1)
                            )
                    )
            }
            .buttonStyle(TVMediaCardButtonStyle())
            .tvOSDisableFocusEffect()
            .focused($focusedHeaderAction, equals: "dl-\(system.id)")
            .scaleEffect(focusedHeaderAction == "dl-\(system.id)" ? 1.1 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedHeaderAction == "dl-\(system.id)")
            .padding(.leading, 8)
        }
    }
    #endif

    /// iOS: single button wrapping the entire header with nested download button
    private func iosSystemHeader(for system: (id: String, name: String, roms: [ROM])) -> some View {
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
                        .font(.system(size: systemNameFontSize, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)

                    Text("\(system.roms.count) ROMs")
                        .font(.system(size: systemRomCountFontSize))
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
                            .font(.system(size: downloadAllIconSize))
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                    }

                    Image(systemName: expandedSystems.contains(system.id) ? "chevron.up" : "chevron.down")
                        .foregroundColor(RetroTheme.retroBlue)
                        .font(.system(size: chevronIconSize, weight: .bold))
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                }
            }
            .padding(.vertical, headerVerticalPadding)
            .padding(.horizontal, headerHorizontalPadding)
            .background(systemHeaderBackground(isFocused: false, systemId: system.id))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var emptyView: some View {
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
        }
    }

    private var expandCollapseButton: some View {
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
    }

    // MARK: - Data

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
                    self.systems = mapping.systems.compactMap { key, value in
                        if let systemIdentifier = SystemIdentifier(rawValue: key) {
                            return (id: key,
                                    name: systemIdentifier.libretroDatabaseName,
                                    roms: value.roms)
                        }
                        return nil
                    }.sorted { $0.name < $1.name }

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
        for rom in system.roms {
            guard let url = URL(string: "https://data.provenance-emu.com/ROMs/\(system.id)/\(rom.file)") else {
                downloadManager.setError(.invalidURL, for: rom.id)
                continue
            }
            downloadManager.download(rom: rom, from: url) { _ in }
        }
    }
}

/// Individual ROM row view with tvOS focus support
struct ROMRowView: View {
    let rom: ROM
    let systemId: String
    @ObservedObject var downloadManager: ROMDownloadManager
    let onDownloaded: (ROM, URL) -> Void

    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false
    @State private var selectedArtwork: URL?

    #if os(tvOS)
    @FocusState private var isFocused: Bool
    #endif

    /// Platform-adaptive row height for 10-foot UI
    private var rowHeight: CGFloat {
        #if os(tvOS)
        return 100
        #else
        return 70
        #endif
    }

    private var nameFontSize: CGFloat {
        #if os(tvOS)
        return 22
        #else
        return 16
        #endif
    }

    private var sizeFontSize: CGFloat {
        #if os(tvOS)
        return 18
        #else
        return 14
        #endif
    }

    /// Whether this row is visually highlighted (focused on tvOS, hovered on iOS/macOS)
    private var isHighlighted: Bool {
        #if os(tvOS)
        return isFocused
        #else
        return isHovered
        #endif
    }

    /// Row content shared by both platforms
    private var rowContent: some View {
        ZStack {
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
                            lineWidth: isHighlighted ? 2.5 : 1.5
                        )
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: isHighlighted ? 6 : 3, x: 0, y: 0)
                )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rom.file)
                        .font(.system(size: nameFontSize, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                        .lineLimit(1)

                    Text(ByteCountFormatter.string(fromByteCount: Int64(rom.size), countStyle: .file))
                        .font(.system(size: sizeFontSize))
                        .foregroundColor(RetroTheme.retroPurple)
                        .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                }
                .padding(.leading, 4)

                Spacer()

                if let artwork = rom.artwork {
                    artworkThumbnails(artwork: artwork)
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
        .frame(height: rowHeight)
    }

    private func artworkThumbnails(artwork: ROMArtwork) -> some View {
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
    }

    var body: some View {
        #if os(tvOS)
        Button {
            startDownload()
        } label: {
            rowContent
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
        .fullScreenCover(item: $selectedArtwork) { url in
            ArtworkFullscreenView(imageURL: url)
        }
        #else
        rowContent
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
        .fullScreenCover(item: $selectedArtwork) { url in
            ArtworkFullscreenView(imageURL: url)
        }
        #endif
    }

    private func startDownload() {
        guard downloadManager.activeDownloads[rom.id] == nil else { return }
        guard let url = URL(string: "https://data.provenance-emu.com/ROMs/\(systemId)/\(rom.file)") else {
            downloadManager.setError(.invalidURL, for: rom.id)
            return
        }
        downloadManager.download(rom: rom, from: url) { _ in }
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

    @State private var glowOpacity: Double = 0.7

    private var iconSize: CGFloat {
        #if os(tvOS)
        return 32
        #else
        return 24
        #endif
    }

    var body: some View {
        Group {
            if let status = downloadManager.activeDownloads[rom.id] {
                switch status {
                case .queued:
                    Image(systemName: "clock.fill")
                        .foregroundColor(RetroTheme.retroPurple)
                        .font(.system(size: iconSize, weight: .bold))
                        .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 3, x: 0, y: 0)
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
                        .font(.system(size: iconSize, weight: .bold))
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
                #if os(tvOS)
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(RetroTheme.retroPink)
                    .font(.system(size: iconSize, weight: .bold))
                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                #else
                Button(action: startDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(RetroTheme.retroPink)
                        .font(.system(size: iconSize, weight: .bold))
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
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

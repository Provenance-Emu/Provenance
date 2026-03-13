//
//  SkinCatalogBrowserView.swift
//  PVUIBase
//
//  Created for Provenance (GitHub issue #2545)
//

import SwiftUI
import PVPrimitives
import PVLogging

/// View for browsing and downloading skins from the remote skin catalog.
///
/// On tvOS this view redirects to `TVOSSkinCatalogBrowserView`, which provides an
/// App Store–style layout suitable for focus-based navigation.
/// On iOS/iPadOS it displays a searchable, filterable grid of available skins
/// from `SkinCatalogService`. Tapping a skin opens `SkinCatalogDetailView`.
public struct SkinCatalogBrowserView: View {

    #if os(tvOS)
    private let preselectedSystem: String?
    public init(preselectedSystem: String? = nil) {
        self.preselectedSystem = preselectedSystem
    }
    public var body: some View {
        TVOSSkinCatalogBrowserView(preselectedSystem: preselectedSystem)
    }
    #else

    // MARK: - State

    @State private var entries: [SkinCatalogEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedSystem: String?
    @State private var selectedDevice: String?
    @State private var sortOption: SkinSortOption = .popular
    @State private var availableSystems: [String] = []
    @State private var glowIntensity: CGFloat = 0.5
    @State private var showingFilters = false
    @State private var isRefreshing = false
    @State private var spinnerRotation: Double = 0
    @State private var filterTask: Task<Void, Never>?

    /// Observe the skin manager so we can show which catalog skins are already installed.
    @StateObject private var skinManager = DeltaSkinManager.shared

    // MARK: - Filter Options

    private let deviceOptions: [(label: String, value: String?)] = [
        ("All Devices", nil),
        ("iPhone", "iphone"),
        ("iPad", "ipad"),
        ("Apple TV", "tv")
    ]

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Init

    /// Create the catalog browser, optionally pre-filtered to a system.
    ///
    /// When `preselectedSystem` is non-nil the filter bar is shown automatically
    /// so the user immediately sees which system is active and can change it.
    public init(preselectedSystem: String? = nil) {
        _selectedSystem = State(initialValue: preselectedSystem)
        _showingFilters = State(initialValue: preselectedSystem != nil)
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                searchBarView
                filterBarView

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if entries.isEmpty {
                    emptyView
                } else {
                    catalogGridView
                }
            }
        }
        .navigationTitle("Skin Catalog")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFilters.toggle()
                } label: {
                    Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                }
                .accessibilityLabel(showingFilters ? "Hide filters" : "Show filters")
                .transaction { $0.animation = nil }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshCatalog() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .none, value: isRefreshing)
                }
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh catalog")
                .transaction { $0.animation = nil }
            }
        }
        #endif
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
            Task { await loadCatalog() }
        }
        .onChange(of: searchText) { _, _ in
            scheduleFilterUpdate()
        }
        .onChange(of: selectedSystem) { _, _ in
            scheduleFilterUpdate()
        }
        .onChange(of: selectedDevice) { _, _ in
            scheduleFilterUpdate()
        }
        .onChange(of: sortOption) { _, _ in
            scheduleFilterUpdate()
        }
    }

    // MARK: - UI Components

    private var headerView: some View {
        VStack(spacing: 6) {
            Text("BROWSE SKINS")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .padding(.top, 16)
                .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.5), radius: 3)

            Text("Download skins from the community catalog")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        .blur(radius: 0.5)
                        .opacity(glowIntensity),
                    alignment: .bottom
                )
        )
    }

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(RetroTheme.retroHorizontalGradient)

            TextField("Search by name, author, or tag...", text: $searchText)
                .foregroundColor(.white)
                .tint(RetroTheme.retroPink)
            #if !os(tvOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            #endif

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var filterBarView: some View {
        if showingFilters {
            VStack(spacing: 8) {
                // System filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All Systems", isSelected: selectedSystem == nil) {
                            selectedSystem = nil
                        }
                        ForEach(availableSystems, id: \.self) { system in
                            filterChip(system.uppercased(), isSelected: selectedSystem == system) {
                                selectedSystem = (selectedSystem == system) ? nil : system
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Device filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(deviceOptions, id: \.label) { option in
                            filterChip(option.label, isSelected: selectedDevice == option.value) {
                                selectedDevice = option.value
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Sort picker
                HStack {
                    Text("SORT:")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)

                    ForEach(SkinSortOption.allCases, id: \.self) { option in
                        filterChip(option.displayName, isSelected: sortOption == option) {
                            sortOption = option
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black.opacity(0.7) : Color.black.opacity(0.3))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? AnyShapeStyle(RetroTheme.retroGradient) : AnyShapeStyle(Color.white.opacity(0.2)),
                                    lineWidth: isSelected ? 1.5 : 0.5
                                )
                        )
                )
                .shadow(color: isSelected ? RetroTheme.retroPink.opacity(0.4) : .clear, radius: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var catalogGridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 200 : 160), spacing: 16)],
                spacing: 20
            ) {
                ForEach(entries) { entry in
                    let isInstalled = skinManager.loadedSkins.contains { $0.identifier == entry.id }
                    NavigationLink(destination: SkinCatalogDetailView(entry: entry)) {
                        CatalogSkinCard(entry: entry, glowIntensity: glowIntensity, isInstalled: isInstalled)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(RetroTheme.retroHorizontalGradient, lineWidth: 4)
                    .frame(width: 70, height: 70)
                    .blur(radius: 2 * glowIntensity)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(RetroTheme.retroHorizontalGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(spinnerRotation))
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            spinnerRotation = 360
                        }
                    }
            }

            Text("LOADING CATALOG")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)

            Text("CATALOG UNAVAILABLE")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button {
                Task { await loadCatalog() }
            } label: {
                Text("TRY AGAIN")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                            )
                    )
                    .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "gamecontroller")
                .font(.system(size: 50))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)

            Text("NO SKINS FOUND")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Text(searchText.isEmpty ? "The catalog has no skins matching your filters." : "No skins match \"\(searchText)\".")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            if !searchText.isEmpty || selectedSystem != nil || selectedDevice != nil {
                Button {
                    searchText = ""
                    selectedSystem = nil
                    selectedDevice = nil
                    Task { await applyFilters() }
                } label: {
                    Text("CLEAR FILTERS")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                                )
                        )
                        .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Data Loading

    private func loadCatalog() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let systems = try await SkinCatalogService.shared.availableSystems()
            await MainActor.run {
                availableSystems = systems
            }

            await applyFilters()

            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func refreshCatalog() async {
        await MainActor.run { isRefreshing = true }
        do {
            _ = try await SkinCatalogService.shared.fetchCatalog(forceRefresh: true)
            let systems = try await SkinCatalogService.shared.availableSystems()
            await MainActor.run {
                availableSystems = systems
            }
            await applyFilters()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        await MainActor.run { isRefreshing = false }
    }

    private func scheduleFilterUpdate() {
        filterTask?.cancel()
        filterTask = Task {
            // Debounce rapid changes (e.g., typing) to avoid flooding the service.
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            await applyFilters()
        }
    }

    private func sortLocally(_ entries: [SkinCatalogEntry], by option: SkinSortOption) -> [SkinCatalogEntry] {
        switch option {
        case .popular:      return entries.sorted { ($0.downloadCount ?? 0) > ($1.downloadCount ?? 0) }
        case .recent:       return entries.sorted { ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast) }
        case .alphabetical: return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .rating:       return entries.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
    }

    private func applyFilters() async {
        do {
            var results: [SkinCatalogEntry]

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let deviceFilter = selectedDevice.map { [$0] }
                results = try await SkinCatalogService.shared.filterSkins(
                    system: selectedSystem,
                    deviceSupport: deviceFilter,
                    sortBy: sortOption
                )
            } else {
                results = try await SkinCatalogService.shared.searchSkins(
                    query: searchText,
                    system: selectedSystem
                )
                // Apply device filter and sort locally on search results.
                // Use prefix matching so "iphone" matches catalog variants like "iphone-x".
                if let device = selectedDevice {
                    let lowerFilter = device.lowercased()
                    results = results.filter { entry in
                        guard let entryDevices = entry.deviceSupport else { return true }
                        return entryDevices.contains { d in
                            let dl = d.lowercased()
                            return dl == lowerFilter || dl.hasPrefix(lowerFilter + "-") || lowerFilter.hasPrefix(dl + "-")
                        }
                    }
                }
                results = sortLocally(results, by: sortOption)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    entries = results
                }
            }
        } catch {
            ELOG("SkinCatalogBrowserView: Filter error: \(error)")
            guard !Task.isCancelled else { return }
            await MainActor.run {
                errorMessage = error.localizedDescription
                withAnimation(.easeOut(duration: 0.2)) {
                    entries = []
                }
            }
        }
    }
    #endif // os(tvOS)
}

// MARK: - CatalogSkinCard (iOS/iPadOS only)

#if !os(tvOS)

/// A grid card representing a single skin catalog entry.
private struct CatalogSkinCard: View {
    let entry: SkinCatalogEntry
    let glowIntensity: CGFloat
    var isInstalled: Bool = false

    private func displayName(forSystemCode code: String) -> String {
        let map: [String: String] = [
            "nes": "NES",
            "snes": "SNES",
            "n64": "N64",
            "gb": "Game Boy",
            "gbc": "Game Boy Color",
            "gba": "Game Boy Advance",
            "mastersystem": "Master System",
            "sms": "SMS",
            "gamegear": "Game Gear",
            "gg": "GG",
            "genesis": "Genesis",
            "megadrive": "Mega Drive",
            "psx": "PlayStation",
            "ps1": "PlayStation"
        ]

        let key = code.lowercased()
        return map[key] ?? code.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with installed badge overlay
            thumbnailView
                .aspectRatio(1.4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
                            .background(Color.black.opacity(0.7).clipShape(Circle()))
                            .padding(6)
                    }
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("by \(entry.author ?? "Unknown")")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // System tags (max 2, excluding legacy codes like "unofficial")
                    let validSystems = entry.systems.filter { !SkinCatalogService.isLegacySystemCode($0) }
                    ForEach(validSystems.prefix(2), id: \.self) { system in
                        Text(displayName(forSystemCode: system))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                                    .overlay(Capsule().strokeBorder(RetroTheme.retroGradient, lineWidth: 0.5))
                            )
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    // Download count
                    if let count = entry.downloadCount, count > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 9))
                            Text(formatSkinDownloadCount(count))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: isInstalled ? 2 : 1)
                )
                .shadow(color: isInstalled ? RetroTheme.retroPink.opacity(0.5) : RetroTheme.retroPurple.opacity(0.3), radius: 6)
        )
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailURL = entry.thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .empty:
                    placeholderThumbnail
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderThumbnail
                @unknown default:
                    placeholderThumbnail
                }
            }
        } else {
            placeholderThumbnail
        }
    }

    private var placeholderThumbnail: some View {
        ZStack {
            Color.black.opacity(0.3)
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 32))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 4)
        }
    }

}
#endif // !os(tvOS)

// MARK: - Shared Helpers

/// Formats a download/play count into a compact string (e.g. 1200 → "1.2k").
func formatSkinDownloadCount(_ count: Int) -> String {
    if count >= 1_000 {
        return String(format: "%.1fk", Double(count) / 1_000.0)
    }
    return "\(count)"
}

// MARK: - SkinSortOption Display (iOS only — used by filterBarView)

#if !os(tvOS)
private extension SkinSortOption {
    var displayName: String {
        switch self {
        case .popular:     return "Popular"
        case .recent:      return "Recent"
        case .alphabetical: return "A–Z"
        case .rating:      return "Rating"
        }
    }
}
#endif // !os(tvOS)

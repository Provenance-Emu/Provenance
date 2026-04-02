//
//  TVOSSkinCatalogBrowserView.swift
//  PVUIBase
//
//  tvOS-specific skin catalog browser.
//  Uses an App Store–style layout with horizontal scrolling rows for
//  "Popular", "New", and "By System" sections.
//  Focus-based navigation is fully compatible with the Siri Remote.
//
//  Issue: #2518
//

#if os(tvOS)
import SwiftUI
import PVPrimitives
import PVSystems
import PVLogging

// MARK: - TVOSSkinCatalogBrowserView

/// tvOS skin catalog browser with App Store–style horizontal sections.
///
/// All skins come from the remote catalog — no document picker is available on tvOS.
/// Download and install is handled by `SkinCatalogDetailView` via `DeltaSkinManager`.
public struct TVOSSkinCatalogBrowserView: View {

    private let activationContextSystemIdentifier: SystemIdentifier?
    private let activationContextGameId: String?

    // MARK: - State

    @State private var catalog: [SkinCatalogEntry] = []
    @State private var availableSystems: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedSystem: String?
    @State private var glowIntensity: CGFloat = 0.5
    @State private var spinnerRotation: Double = 0
    @State private var searchTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates the browser, optionally pre-filtering to a system.
    public init(
        preselectedSystem: String? = nil,
        activationContextSystemIdentifier: SystemIdentifier? = nil,
        activationContextGameId: String? = nil
    ) {
        _selectedSystem = State(initialValue: preselectedSystem)
        self.activationContextSystemIdentifier = activationContextSystemIdentifier
        self.activationContextGameId = activationContextGameId
    }

    @ViewBuilder
    private func catalogDetailDestination(for entry: SkinCatalogEntry) -> some View {
        SkinCatalogDetailView(
            entry: entry,
            activationContextSystemIdentifier: activationContextSystemIdentifier,
            activationContextGameId: activationContextGameId
        )
    }

    // MARK: - Derived data

    /// Expanded system filter codes based on shared skin-layout groups.
    ///
    /// For example, selecting `genesis` also includes `segacd` and `32x`.
    private var selectedSystemFilterCodes: Set<String>? {
        guard let selectedSystem else { return nil }
        return SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: selectedSystem)
    }

    /// Catalog entries after applying the optional selected-system filter.
    private var filteredCatalog: [SkinCatalogEntry] {
        guard let filterCodes = selectedSystemFilterCodes else { return catalog }
        return catalog.filter { entry in
            let entryCodes = Set(entry.systems.map { $0.lowercased() })
            return !entryCodes.isDisjoint(with: filterCodes)
        }
    }

    private var popularSkins: [SkinCatalogEntry] {
        filteredCatalog
            .sorted { ($0.downloadCount ?? 0) > ($1.downloadCount ?? 0) }
            .prefix(12)
            .map { $0 }
    }

    private var newSkins: [SkinCatalogEntry] {
        filteredCatalog
            .sorted { ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast) }
            .prefix(12)
            .map { $0 }
    }

    private var skinsBySystem: [(system: String, skins: [SkinCatalogEntry])] {
        // Group by the first non-legacy system code (normalized to lowercase).
        let grouped = Dictionary(grouping: filteredCatalog) { entry -> String in
            entry.systems
                .map { $0.lowercased() }
                .first { !SkinCatalogService.isLegacySystemCode($0) }
                ?? "other"
        }
        return grouped
            .filter { !SkinCatalogService.isLegacySystemCode($0.key) }
            .map { (system: $0.key, skins: $0.value) }
            .sorted { $0.system < $1.system }
    }

    private var searchResults: [SkinCatalogEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return filteredCatalog.filter {
            $0.name.lowercased().contains(q)
            || ($0.author?.lowercased().contains(q) ?? false)
            || $0.systems.contains(where: { $0.lowercased().contains(q) })
            || ($0.tags?.contains(where: { $0.lowercased().contains(q) }) ?? false)
        }
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if !searchText.isEmpty {
                searchResultsView
            } else {
                catalogContentView
            }
        }
        .navigationTitle("Browse Skins")
        .searchable(text: $searchText, prompt: "Search by name, author, or tag")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
            Task { await loadCatalog() }
        }
        .onChange(of: searchText) { _ in
            scheduleSearchUpdate()
        }
    }

    // MARK: - Main catalog content

    private var catalogContentView: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 40) {
                // System filter chips (horizontal)
                if !availableSystems.isEmpty {
                    systemFilterRow
                }

                // Popular section
                if !popularSkins.isEmpty {
                    sectionRow(title: "POPULAR", skins: popularSkins)
                }

                // New / Recently Updated section
                if !newSkins.isEmpty {
                    sectionRow(title: "NEW & UPDATED", skins: newSkins)
                }

                // By System sections
                ForEach(skinsBySystem, id: \.system) { item in
                    if selectedSystem == nil || selectedSystemFilterCodes?.contains(item.system) == true {
                        sectionRow(title: SystemIdentifier.displayName(forCatalogCode: item.system), skins: item.skins)
                    }
                }
            }
            .padding(.vertical, 40)
        }
    }

    // MARK: - System filter row

    private var systemFilterRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("FILTER BY SYSTEM")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    systemChip("All", isSelected: selectedSystem == nil) {
                        withAnimation { selectedSystem = nil }
                    }
                    ForEach(availableSystems, id: \.self) { system in
                        systemChip(SystemIdentifier.displayName(forCatalogCode: system), isSelected: selectedSystem == system) {
                            withAnimation { selectedSystem = (selectedSystem == system) ? nil : system }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 8)
            }
        }
        .padding(.leading, 60)
    }

    private func systemChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(1)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black.opacity(0.7) : Color.black.opacity(0.3))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? AnyShapeStyle(RetroTheme.retroGradient) : AnyShapeStyle(Color.white.opacity(0.2)),
                                    lineWidth: isSelected ? 2 : 0.5
                                )
                        )
                )
                .shadow(color: isSelected ? RetroTheme.retroPink.opacity(0.5) : .clear, radius: 6)
        }
        .retroFocusButtonStyle(focusScale: 1.05, cornerRadius: 30)
    }

    // MARK: - Horizontal section row

    private func sectionRow(title: String, skins: [SkinCatalogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title)
                .padding(.leading, 60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(skins) { entry in
                        NavigationLink(destination: catalogDetailDestination(for: entry)) {
                            TVOSSkinCard(entry: entry, glowIntensity: glowIntensity)
                        }
                        .retroFocusButtonStyle(focusScale: 1.08, cornerRadius: 16)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Search results

    private var searchResultsView: some View {
        Group {
            if searchResults.isEmpty {
                emptySearchView
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 30)],
                        spacing: 30
                    ) {
                        ForEach(searchResults) { entry in
                            NavigationLink(destination: catalogDetailDestination(for: entry)) {
                                TVOSSkinCard(entry: entry, glowIntensity: glowIntensity)
                            }
                            .retroFocusButtonStyle(focusScale: 1.08, cornerRadius: 16)
                        }
                    }
                    .padding(60)
                }
            }
        }
    }

    private var emptySearchView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 6)

            Text("NO RESULTS")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Text("No skins match \"\(searchText)\".")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading view

    private var loadingView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(RetroTheme.retroHorizontalGradient, lineWidth: 6)
                    .frame(width: 100, height: 100)
                    .blur(radius: 3 * glowIntensity)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(RetroTheme.retroHorizontalGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(spinnerRotation))
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 6)
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            spinnerRotation = 360
                        }
                    }
            }

            Text("LOADING CATALOG")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(3)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error view

    private func errorView(message: String) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 80))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 6)

            Text("CATALOG UNAVAILABLE")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Text(message)
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 80)

            Button {
                Task { await loadCatalog() }
            } label: {
                Text("TRY AGAIN")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                            )
                    )
                    .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 8)
            }
            .retroFocusButtonStyle()

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(RetroTheme.retroHorizontalGradient)
            .tracking(2)
            .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.4), radius: 3)
    }

    // MARK: - Data loading

    private func loadCatalog() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let skinCatalog = try await SkinCatalogService.shared.fetchCatalog(forceRefresh: false)
            let systems = try await SkinCatalogService.shared.availableSystems()

            await MainActor.run {
                catalog = skinCatalog.skins
                availableSystems = systems
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func scheduleSearchUpdate() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            // Search filtering is computed from catalog state directly.
        }
    }
}

// MARK: - TVOSSkinCard

/// A large card for the tvOS skin catalog — optimised for 10-foot viewing.
private struct TVOSSkinCard: View {
    let entry: SkinCatalogEntry
    let glowIntensity: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailView
                .frame(width: 280, height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("by \(entry.author ?? "Unknown")")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // System tags (up to 2, excluding legacy codes)
                    let validSystems = entry.systems
                        .map { $0.lowercased() }
                        .filter { !SkinCatalogService.isLegacySystemCode($0) }
                    ForEach(validSystems.prefix(2), id: \.self) { system in
                        Text(SystemIdentifier.displayName(forCatalogCode: system))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                                    .overlay(Capsule().strokeBorder(RetroTheme.retroGradient, lineWidth: 0.5))
                            )
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    if let count = entry.downloadCount, count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 14))
                            Text(formatSkinDownloadCount(count))
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                )
                .shadow(color: RetroTheme.retroPurple.opacity(0.3), radius: 8)
        )
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let url = entry.thumbnailURL {
            AsyncImage(url: url) { phase in
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
                .font(.system(size: 50))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 6)
        }
    }
}

#endif

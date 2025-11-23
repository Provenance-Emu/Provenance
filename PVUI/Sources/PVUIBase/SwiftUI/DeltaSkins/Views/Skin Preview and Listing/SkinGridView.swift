//
//  SkinGridView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/25.
//

import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif

/// Grid view with loading and error states
struct SkinGridView: View {
    @ObservedObject var manager: DeltaSkinManager
    let columns: [GridItem]

    @State private var isLoading = true
    @State private var error: Error?
    @State private var hasAttemptedLoad = false

    /// Stores the expanded state of each console section as a comma-separated list of expanded section names
    @AppStorage("deltaSkinSectionStates") private var expandedSectionsString: String = ""

    /// Set of expanded section names for faster lookup
    @State private var expandedSections: Set<String> = []

    // Use manager's loadedSkins directly
    private var groupedSkins: [(String, [any DeltaSkinProtocol])] {
        let grouped = Dictionary(grouping: manager.loadedSkins) { skin in
            skin.gameType.systemIdentifier?.fullName ?? (skin.gameType.deltaIdentifierString ?? skin.gameType.manicIdentifierString ?? String(describing: skin.gameType))
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // Create an ordered list that matches the visual grouping
    private var orderedSkins: [any DeltaSkinProtocol] {
        groupedSkins.flatMap { _, consoleSkins in consoleSkins }
    }

    /// Custom transition for section content
    private var sectionTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -20)),
            removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -20))
        )
    }

    /// Loading view
    private var loadingView: some View {
        ProgressView("Loading skins...")
            .backgroundStyle(.blendMode(.darken))
    }

    /// Empty state view
    @ViewBuilder
    private var emptyStateView: some View {
        if #available(iOS 17.0, tvOS 17.0, *) {
            ContentUnavailableView(
                "No Skins Found",
                systemImage: "gamecontroller",
                description: Text("Add skins to get started")
            )
        } else {
            VStack {
                Text("No Skins Found")
                Text("Add skins to get started")
            }
        }
    }

    /// Main content view with skins
    private var skinsContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(groupedSkins, id: \.0) { consoleName, consoleSkins in
                    skinSectionView(consoleName: consoleName, consoleSkins: consoleSkins)
                }

                // DeltaStyles link component
                DeltaStylesLinkView()
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
    }

    /// Individual skin section view
    @ViewBuilder
    private func skinSectionView(consoleName: String, consoleSkins: [any DeltaSkinProtocol]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with disclosure button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    toggleSection(consoleName)
                }
            } label: {
                HStack {
                    Text(consoleName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Image(systemName: isExpanded(consoleName) ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.headline)
                        .rotationEffect(.degrees(isExpanded(consoleName) ? 0 : -90))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded(consoleName))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // Grid of skins for this console
            if isExpanded(consoleName) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(consoleSkins, id: \.identifier) { skin in
                        NavigationLink {
                            PagedSkinTestView(
                                skins: orderedSkins,
                                initialIndex: orderedSkins.firstIndex(where: { $0.identifier == skin.identifier }) ?? 0
                            )
                        } label: {
                            SkinPreviewCell(skin: skin, manager: manager)
                        }
                    }
                }
                .padding(.horizontal)
                .transition(sectionTransition)
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                ErrorView(error: error)
            } else if manager.loadedSkins.isEmpty {
                emptyStateView
            } else {
                skinsContentView
            }
        }
        .background(Color.systemGroupedBackground)
        .onAppear {
            // Check if skins are already loaded (from background scan or previous load)
            if !manager.loadedSkins.isEmpty {
                // Skins are already loaded, stop loading and initialize sections
                isLoading = false
                hasAttemptedLoad = true
                initializeSectionStates()
            } else if !hasAttemptedLoad {
                // Skins are empty and we haven't attempted to load yet
                Task {
                    await loadSkins()
                }
            } else {
                // We've attempted to load but skins are still empty
                // This might mean the scan is still in progress or failed
                // Keep loading state as is (will be updated by onChange)
            }
        }
        .onChange(of: manager.loadedSkins.count) { newCount in
            // When loadedSkins updates, stop loading and initialize sections
            if newCount > 0 {
                isLoading = false
                if expandedSections.isEmpty {
                    initializeSectionStates()
                }
            }
        }
        .onChange(of: expandedSections) { newValue in
            expandedSectionsString = newValue.sorted().joined(separator: ",")
        }
    }

    /// Initialize section states to expanded by default
    private func initializeSectionStates() {
        // Convert stored string to Set
        let storedSections = Set(expandedSectionsString.split(separator: ",").map(String.init))

        // If we have stored states, use them
        if !expandedSectionsString.isEmpty {
            expandedSections = storedSections
        } else {
            // Otherwise, initialize all sections as expanded
            expandedSections = Set(groupedSkins.map { $0.0 })
            // Update stored string
            expandedSectionsString = expandedSections.sorted().joined(separator: ",")
        }
    }

    /// Toggle the expanded state of a section
    private func toggleSection(_ consoleName: String) {
        if expandedSections.contains(consoleName) {
            expandedSections.remove(consoleName)
        } else {
            expandedSections.insert(consoleName)
        }
    }

    /// Check if a section is expanded
    private func isExpanded(_ consoleName: String) -> Bool {
        expandedSections.contains(consoleName)
    }

    private func loadSkins() async {
        hasAttemptedLoad = true

        // Only show loading if skins haven't been loaded yet
        if manager.loadedSkins.isEmpty {
            await MainActor.run {
                isLoading = true
            }
        }

        do {
            // Load skins - this will trigger scanForSkins if needed
            // Note: scanForSkins updates loadedSkins asynchronously on main thread,
            // so we need to wait for that update via onChange(of: manager.loadedSkins)
            _ = try await manager.availableSkins(forceRescan: false)

            // Check if skins were loaded (they might already be loaded from previous scan)
            // The onChange handler will catch the update if it happens asynchronously
            await MainActor.run {
                if !manager.loadedSkins.isEmpty {
                    isLoading = false
                    if expandedSections.isEmpty {
                        initializeSectionStates()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func index(of skin: any DeltaSkinProtocol) -> Int {
        manager.loadedSkins.firstIndex(where: { $0.identifier == skin.identifier }) ?? 0
    }
}

/// Error view
private struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("Error Loading Skins")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

/// View component for linking to DeltaStyles website
private struct DeltaStylesLinkView: View {
    @State private var showSafariView = false

    private let deltaStylesURL = URL(string: "https://deltastyles.com")!

    var body: some View {
        VStack(spacing: 12) {
            // Info label
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Download more skins from DeltaStyles")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Button to open DeltaStyles
            #if !os(tvOS)
            Button {
                showSafariView = true
            } label: {
                HStack {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.pink, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Visit DeltaStyles.com")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.pink, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.pink, .blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
            .sheet(isPresented: $showSafariView) {
                SafariWebView(url: deltaStylesURL, entersReaderIfAvailable: false)
            }
            #else
            Link(destination: deltaStylesURL) {
                HStack {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.pink, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Visit DeltaStyles.com")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.pink, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.pink, .blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
            #endif
        }
        .padding(.vertical, 8)
    }
}

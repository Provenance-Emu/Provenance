//
//  SkinGridView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/25.
//

import SwiftUI

/// Grid view with loading and error states
struct SkinGridView: View {
    @ObservedObject var manager: DeltaSkinManager
    let columns: [GridItem]

    @State private var isLoading = true
    @State private var error: Error?

    /// Stores the expanded state of each console section as a comma-separated list of expanded section names
    @AppStorage("deltaSkinSectionStates") private var expandedSectionsString: String = ""

    /// Set of expanded section names for faster lookup
    @State private var expandedSections: Set<String> = []

    // Use manager's loadedSkins directly
    private var groupedSkins: [(String, [any DeltaSkinProtocol])] {
        let grouped = Dictionary(grouping: manager.loadedSkins) { skin in
            skin.gameType.systemIdentifier?.fullName ?? skin.gameType.rawValue
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

    var body: some View {
        Group {
            switch (isLoading, error, manager.loadedSkins.isEmpty) {
            case (true, _, _):
                ProgressView("Loading skins...")
                    .backgroundStyle(.blendMode(.darken))
            case (_, let error?, _):
                ErrorView(error: error)
            case (_, _, true):
                if #available(iOS 17.0, tvOS 17.0, *) {
                    ContentUnavailableView(
                        "No Skins Found",
                        systemImage: "gamecontroller",
                        description: Text("Add skins to get started")
                    )
                } else {
                    // Fallback on earlier versions
                    Text("No Skins Found")
                    Text("Add skins to get started")
                }
            default:
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(groupedSkins, id: \.0) { consoleName, consoleSkins in
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
                    }
                }
            }
        }
        .background(Color.systemGroupedBackground)
        .task {
            await loadSkins()
            initializeSectionStates()
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
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await manager.availableSkins()  // This will update loadedSkins
        } catch {
            self.error = error
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

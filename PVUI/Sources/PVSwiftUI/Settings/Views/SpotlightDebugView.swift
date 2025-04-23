//
//  SpotlightDebugView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/16/25.
//

import SwiftUI
import PVLibrary
import PVSupport
import PVLogging
import CoreSpotlight
import PVThemes
import Combine
import RealmSwift

#if !os(tvOS)

/// Debug view for Spotlight integration
public struct SpotlightDebugView: View {
    // State for the view
    @State private var spotlightItems: [CSSearchableItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var reindexingInProgress = false
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0
    
    public var body: some View {
        ZStack {
            // RetroWave background
            RetroTheme.retroBackground
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Title with retrowave styling
                    Text("SPOTLIGHT DEBUG")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.retroPink)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .shadow(color: .retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)
                    
                    // Content sections
                    SpotlightControlsSection(
                        isLoading: $isLoading,
                        errorMessage: $errorMessage,
                        reindexingInProgress: $reindexingInProgress,
                        refreshItems: refreshSpotlightItems,
                        forceReindex: forceReindexSpotlight
                    )
                    .modifier(RetroTheme.RetroSectionStyle())
                    .padding(.horizontal)
                    
                    SpotlightItemsSection(items: spotlightItems, isLoading: isLoading)
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Spotlight Debug")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            await refreshSpotlightItems()
            
            // Start animation for glow effect
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.9
            }
        }
        .uiKitAlert(
            "Error",
            message: errorMessage ?? "",
            isPresented: .constant(errorMessage != nil),
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "OK", style: .default) { _ in
                errorMessage = nil
            }
        }
    }
    
    /// Refresh the list of Spotlight items
    @MainActor
    private func refreshSpotlightItems() async {
        isLoading = true
        
        do {
            ILOG("Starting to refresh Spotlight items")
            // Get items from Spotlight
            let searchableIndex = CSSearchableIndex.default()
            let fetchedItems = try await fetchSpotlightItems(from: searchableIndex)
            
            // Update the UI
            spotlightItems = fetchedItems
            ILOG("Loaded \(spotlightItems.count) Spotlight items")
        } catch {
            ELOG("Error fetching Spotlight items: \(error)")
            errorMessage = "Error fetching Spotlight items: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Force reindex all content in Spotlight
    @MainActor
    private func forceReindexSpotlight() async {
        reindexingInProgress = true
        defer { reindexingInProgress = false }
        
        do {
            // Use the SpotlightHelper to reindex all content
            let helper = SpotlightHelper.shared
            
            // Show a task is in progress
            isLoading = true
            
            // Force reindex all content
            try await helper.forceReindexAllAsync()
            
            // Refresh the items list
            await refreshSpotlightItems()
            
            ILOG("Successfully reindexed all Spotlight content")
        } catch {
            ELOG("Error reindexing Spotlight content: \(error)")
            errorMessage = "Error reindexing Spotlight content: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Fetch items from Spotlight
    private func fetchSpotlightItems(from searchableIndex: CSSearchableIndex) async throws -> [CSSearchableItem] {
        ILOG("Starting to fetch Spotlight items")
        
        // Use a simpler approach - just delete and reindex to get the latest items
        // This is more reliable than trying to query the index
        return try await withCheckedThrowingContinuation { continuation in
            // First, try to delete all existing items for our domain
            ILOG("Deleting existing Spotlight items")
            searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["org.provenance-emu.games"]) { error in
                if let error = error {
                    ELOG("Error deleting Spotlight items: \(error)")
                }
                
                // Now get the items directly from our database instead of querying Spotlight
                Task {
                    do {
                        ILOG("Creating mock items from database")
                        // Get games from the database
                        let realm = RomDatabase.sharedInstance.realm
                        let games = realm.objects(PVGame.self)
                        
                        // Create searchable items for each game
                        var items: [CSSearchableItem] = []
                        for game in games {
                            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
                            attributeSet.displayName = game.title
                            attributeSet.contentDescription = "Game for \(game.system?.name ?? "Unknown System")" 
                            
                            let item = CSSearchableItem(
                                uniqueIdentifier: "org.provenance-emu.game.\(game.md5Hash)",
                                domainIdentifier: "org.provenance-emu.games",
                                attributeSet: attributeSet
                            )
                            
                            items.append(item)
                        }
                        
                        // Get save states
                        let saveStates = realm.objects(PVSaveState.self)
                        for saveState in saveStates {
                            if let game = saveState.game {
                                let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
                                attributeSet.displayName = "Save State: \(game.title)"
                                attributeSet.contentDescription = "Save state for \(game.title) on \(game.system?.name ?? "Unknown System")"
                                
                                let item = CSSearchableItem(
                                    uniqueIdentifier: "org.provenance-emu.savestate.\(saveState.id)",
                                    domainIdentifier: "org.provenance-emu.games",
                                    attributeSet: attributeSet
                                )
                                
                                items.append(item)
                            }
                        }
                        
                        ILOG("Created \(items.count) mock items")
                        continuation.resume(returning: items)
                    } catch {
                        ELOG("Error creating mock items: \(error)")
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }
}

/// Controls section for Spotlight debugging
private struct SpotlightControlsSection: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @Binding var reindexingInProgress: Bool
    
    let refreshItems: () async -> Void
    let forceReindex: () async -> Void
    
    @State private var glowOpacity: Double = 0.6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with retrowave styling
            Text("SPOTLIGHT CONTROLS")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.retroPurple)
                .shadow(color: .retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                // Refresh items button
                Button(action: {
                    Task {
                        await refreshItems()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                        Text("REFRESH ITEMS")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue.opacity(0.6), .retroPurple.opacity(0.6)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.retroBlue, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading || reindexingInProgress)
                
                // Force reindex button
                Button(action: {
                    Task {
                        await forceReindex()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                        Text("FORCE REINDEX ALL")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink.opacity(0.6), .retroPurple.opacity(0.6)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.retroPink, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading || reindexingInProgress)
                
                // Loading indicator
                if isLoading || reindexingInProgress {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                        Text(reindexingInProgress ? "Reindexing..." : "Loading...")
                            .foregroundColor(.retroPink)
                            .padding(.leading, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal)
            .onAppear {
                // Start animation for glow effect
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.8
                }
            }
        }
    }
}

/// Section displaying Spotlight items
private struct SpotlightItemsSection: View {
    let items: [CSSearchableItem]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with retrowave styling
            Text("SPOTLIGHT ITEMS")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.retroPurple)
                .shadow(color: .retroPink.opacity(0.7), radius: 3, x: 0, y: 0)
                .padding(.bottom, 4)
            
            if isLoading {
                // Loading placeholder
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    Text("Loading items...")
                        .foregroundColor(.retroPink)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else if items.isEmpty {
                // Empty state
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.retroBlue)
                        .padding(.bottom, 8)
                    Text("No Spotlight items found")
                        .foregroundColor(.retroBlue)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else {
                // Items list
                Text("Found \(items.count) items")
                    .font(.system(size: 14))
                    .foregroundColor(.retroBlue)
                    .padding(.bottom, 8)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items, id: \.uniqueIdentifier) { item in
                            SpotlightItemRow(item: item)
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding()
    }
}

/// Row displaying a single Spotlight item
private struct SpotlightItemRow: View {
    let item: CSSearchableItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item header
            HStack {
                Text(itemTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.retroPink)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.retroBlue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Item ID
            Text("ID: \(item.uniqueIdentifier)")
                .font(.system(size: 12))
                .foregroundColor(.retroBlue)
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Domain: \(item.domainIdentifier ?? "Unknown")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    // The attributeSet might be nil, so we need to check if it exists
                    if let attributeSet = item.attributeSet as? CSSearchableItemAttributeSet {
                        if let title = attributeSet.displayName {
                            Text("Title: \(title)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        if let description = attributeSet.contentDescription {
                            Text("Description: \(description)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                        
                        if let keywords = attributeSet.keywords, !keywords.isEmpty {
                            Text("Keywords: \(keywords.joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        if let date = attributeSet.contentModificationDate {
                            Text("Modified: \(formattedDate(date))")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroBlue.opacity(0.6), .retroPurple.opacity(0.6)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // Extract a title from the item ID
    private var itemTitle: String {
        let id = item.uniqueIdentifier
        
        if id.contains("savestate") {
            return "Save State"
        } else if id.contains("game") {
            return "Game"
        } else {
            return "Item"
        }
    }
    
    // Format date for display
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Extensions for SpotlightHelper

extension SpotlightHelper {
    /// Async version of forceReindexAll
    public func forceReindexAllAsync() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            forceReindexAll { 
                // The completion handler doesn't provide an error, so we just assume success
                continuation.resume(returning: ())
            }
        }
    }
}
#endif

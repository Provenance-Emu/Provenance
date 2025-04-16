//
//  BatchArtworkMatchingView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/16/25.
//

import SwiftUI
import PVLibrary
import PVSupport
import PVLogging
import PVLookup
import PVLookupTypes
import PVSystems
import RealmSwift
import PVMediaCache
import PVUIBase

/// View for batch matching artwork to games without artwork
public struct BatchArtworkMatchingView: View {
    // MARK: - Properties
    
    // State for filtering and processing
    @State private var includeGamesWithOriginalArtwork = false
    @State private var isLoading = false
    @State private var processingGames = false
    @State private var searchProgress: Double = 0
    @State private var errorMessage: String?
    
    // Game and artwork data
    @State private var gamesNeedingArtwork: [PVGame] = []
    @State private var artworkResults: [String: ArtworkMetadata] = [:]
    @State private var selectedArtworks: Set<String> = []
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // RetroWave background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Grid background
            RetroGridForSettings()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.5)
            
            // Main content
            VStack(spacing: 16) {
                // Title with retrowave styling
                Text("BATCH ARTWORK MATCHER")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.retroPink)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)
                
                // Filter controls
                filterControls
                    .padding(.horizontal)
                
                // Action buttons
                actionButtons
                    .padding(.horizontal)
                
                // Content area
                if isLoading {
                    loadingView
                } else if processingGames {
                    processingView
                } else if gamesNeedingArtwork.isEmpty {
                    emptyStateView
                } else {
                    gamesList
                }
                
                // Bottom action bar
                if !selectedArtworks.isEmpty {
                    selectionActionBar
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Batch Artwork Matcher")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Start animation for glow effect
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.9
            }
            
            // Load games on first appearance
            await loadGamesNeedingArtwork()
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
    
    // MARK: - UI Components
    
    /// Filter controls for the view
    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with retrowave styling
            Text("FILTER OPTIONS")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.retroPurple)
                .shadow(color: .retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                .padding(.bottom, 4)
            
            // Include games with original artwork toggle
            Toggle(isOn: $includeGamesWithOriginalArtwork) {
                Text("Include games with original artwork")
                    .foregroundColor(.white)
            }
            .toggleStyle(SwitchToggleStyle(tint: .retroPink))
            .onChange(of: includeGamesWithOriginalArtwork) { _ in
                Task {
                    await loadGamesNeedingArtwork()
                }
            }
            
            // Game count
            Text("\(gamesNeedingArtwork.count) games need artwork")
                .font(.system(size: 14))
                .foregroundColor(.retroBlue)
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    /// Action buttons for the view
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Find Artwork button
            Button(action: {
                Task {
                    await findArtworkForGames()
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                    Text("FIND ARTWORK")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
            .disabled(isLoading || processingGames || gamesNeedingArtwork.isEmpty)
            
            // Refresh button
            Button(action: {
                Task {
                    await loadGamesNeedingArtwork()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                    Text("REFRESH LIST")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPurple.opacity(0.6), .retroPink.opacity(0.6)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.retroPurple, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading || processingGames)
        }
    }
    
    /// Loading view shown during initial load
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                .scaleEffect(1.5)
            
            Text("Loading games...")
                .font(.headline)
                .foregroundColor(.retroPink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Processing view shown during artwork search
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: searchProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .retroPink))
                .frame(width: 200)
            
            Text("Searching for artwork: \(Int(searchProgress * 100))%")
                .font(.headline)
                .foregroundColor(.retroPink)
            
            Text("\(artworkResults.count) matches found so far")
                .font(.subheadline)
                .foregroundColor(.retroBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Empty state view when no games need artwork
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.retroBlue)
            
            Text("All games have artwork!")
                .font(.headline)
                .foregroundColor(.retroPink)
            
            Text("Try including games with original artwork to find better matches")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// List of games needing artwork
    private var gamesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(gamesNeedingArtwork, id: \.md5Hash) { game in
                    GameArtworkRow(
                        game: game,
                        artworkResult: artworkResults[game.md5Hash ?? ""],
                        isSelected: selectedArtworks.contains(game.md5Hash ?? ""),
                        onToggleSelection: { toggleSelection(for: game) }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    /// Bottom action bar for selected items
    private var selectionActionBar: some View {
        HStack {
            Text("\(selectedArtworks.count) selected")
                .foregroundColor(.white)
                .padding(.leading)
            
            Spacer()
            
            Button(action: {
                selectedArtworks.removeAll()
            }) {
                Text("Clear")
                    .foregroundColor(.retroBlue)
            }
            .padding(.horizontal)
            
            Button(action: {
                Task {
                    await applySelectedArtwork()
                }
            }) {
                Text("Apply Selected")
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .padding(.trailing)
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Methods
    
    /// Load games that need artwork
    private func loadGamesNeedingArtwork() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get all games from the database
            let realm = RomDatabase.sharedInstance.realm
            
            // Build query based on filter settings
            var predicates: [NSPredicate] = []
            
            if includeGamesWithOriginalArtwork {
                // Include games that don't have custom artwork
                predicates.append(NSPredicate(format: "customArtworkURL == ''"))
            } else {
                // Only include games that don't have any artwork
                predicates.append(NSPredicate(format: "customArtworkURL == '' AND originalArtworkURL == ''"))
            }
            
            // Combine predicates
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            // Get games matching our criteria
            let results = realm.objects(PVGame.self).filter(predicate)
            
            // Convert to array of frozen objects for thread safety
            gamesNeedingArtwork = results.map { $0.freeze() }
            
            ILOG("Found \(gamesNeedingArtwork.count) games needing artwork")
            
            // Clear previous results
            artworkResults.removeAll()
            selectedArtworks.removeAll()
        } catch {
            ELOG("Error loading games: \(error)")
            errorMessage = "Error loading games: \(error.localizedDescription)"
        }
    }
    
    /// Find artwork for all games in the list
    private func findArtworkForGames() async {
        guard !gamesNeedingArtwork.isEmpty else { return }
        
        processingGames = true
        searchProgress = 0.0
        artworkResults.removeAll()
        selectedArtworks.removeAll()
        
        do {
            // Process games in batches to avoid overwhelming the system
            let totalGames = gamesNeedingArtwork.count
            
            for (index, game) in gamesNeedingArtwork.enumerated() {
                // Update progress
                searchProgress = Double(index) / Double(totalGames)
                
                // Skip games without an MD5 hash
                let md5 = game.md5Hash
                guard !md5.isEmpty else { continue }
                
                // Clean the game title for search
                let searchTitle = game.title.cleanedForSearch()
                
                // Search for artwork
                if let results = try await PVLookup.shared.searchArtwork(
                    byGameName: searchTitle,
                    systemID: SystemIdentifier(rawValue: game.systemIdentifier),
                    artworkTypes: [.boxFront]  // Only look for box front art
                ), let firstResult = results.first {
                    // Store the first result
                    artworkResults[md5] = firstResult
                    
                    // Automatically select this result
                    selectedArtworks.insert(md5)
                }
                
                // Small delay to avoid hammering the API
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            }
            
            // Complete progress
            searchProgress = 1.0
            
            // Log results
            ILOG("Found artwork for \(artworkResults.count) out of \(totalGames) games")
        } catch {
            ELOG("Error searching for artwork: \(error)")
            errorMessage = "Error searching for artwork: \(error.localizedDescription)"
        }
        
        processingGames = false
    }
    
    /// Toggle selection for a game
    private func toggleSelection(for game: PVGame) {
        let md5 = game.md5Hash
        guard !md5.isEmpty else { return }
        
        if selectedArtworks.contains(md5) {
            selectedArtworks.remove(md5)
        } else {
            selectedArtworks.insert(md5)
        }
    }
    
    /// Apply selected artwork to games
    private func applySelectedArtwork() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get a writable Realm instance
            let realm = RomDatabase.sharedInstance.realm
            
            // Track successful updates
            var successCount = 0
            
            // Process each selected game
            for md5 in selectedArtworks {
                // Get the artwork result
                guard let artwork = artworkResults[md5] else { continue }
                
                // Find the game in the database
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) else { continue }
                
                // Download the artwork
                do {
                    let (data, _) = try await URLSession.shared.data(from: artwork.url)
                    
                    #if os(macOS)
                    if let image = NSImage(data: data) {
                        // Generate a unique ID for this artwork
                        let uniqueID = UUID().uuidString
                        let key = "artwork_\(md5)_\(uniqueID)"
                        
                        // Write the image to the media cache
                        let localURL = try PVMediaCache.writeImage(toDisk: image, withKey: key)
                        
                        // Update the game in a write transaction
                        try realm.write {
                            let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                            game.customArtworkURL = key
                            game.customArtworkFile = file
                        }
                        
                        successCount += 1
                    }
                    #else
                    if let image = UIImage(data: data) {
                        // Generate a unique ID for this artwork
                        let uniqueID = UUID().uuidString
                        let key = "artwork_\(md5)_\(uniqueID)"
                        
                        // Write the image to the media cache
                        let localURL = try PVMediaCache.writeImage(toDisk: image, withKey: key)
                        
                        // Update the game in a write transaction
                        try realm.write {
                            game.customArtworkURL = key
                        }
                        
                        successCount += 1
                    }
                    #endif
                } catch {
                    ELOG("Error downloading artwork for game \(game.title): \(error)")
                }
            }
            
            // Log results
            ILOG("Successfully applied artwork to \(successCount) games")
            
            // Reload the list to reflect changes
            await loadGamesNeedingArtwork()
        } catch {
            ELOG("Error applying artwork: \(error)")
            errorMessage = "Error applying artwork: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

/// Row for displaying a game and its potential artwork match
struct GameArtworkRow: View {
    let game: PVGame
    let artworkResult: ArtworkMetadata?
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    @State private var artworkImage: Image?
    @State private var isLoading = false
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection checkbox
            if artworkResult != nil {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .retroPink : .gray)
                        .font(.system(size: 20))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Game info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                if let systemName = game.system?.name {
                    Text(systemName)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Artwork preview
            Group {
                if let artworkResult = artworkResult {
                    if let artworkImage = artworkImage {
                        artworkImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    } else if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                            .frame(width: 80, height: 80)
                    } else {
                        Color.black.opacity(0.3)
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                            .onAppear {
                                loadArtwork(from: artworkResult.url)
                            }
                    }
                } else {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.gray)
                        .frame(width: 80, height: 80)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: isSelected ? 
                                                 [.retroPink, .retroPurple] : 
                                                 [.retroBlue.opacity(0.5), .retroPurple.opacity(0.5)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: isHovered ? 1.5 : 0.5
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
#if !os(tvOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }
    
    /// Load artwork image from URL
    private func loadArtwork(from url: URL) {
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                #if os(macOS)
                if let nsImage = NSImage(data: data) {
                    await MainActor.run {
                        artworkImage = Image(nsImage: nsImage)
                        isLoading = false
                    }
                }
                #else
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        artworkImage = Image(uiImage: uiImage)
                        isLoading = false
                    }
                }
                #endif
            } catch {
                await MainActor.run {
                    isLoading = false
                    ELOG("Error loading artwork: \(error)")
                }
            }
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Clean a string for artwork search
    func cleanedForSearch() -> String {
        var cleaned = self
        
        // Remove text in brackets: [], (), {}
        let bracketPatterns = ["\\[.*?\\]", "\\(.*?\\)", "\\{.*?\\}"]
        for pattern in bracketPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count), withTemplate: "")
            }
        }
        
        // Remove special characters
        let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ")).inverted
        cleaned = cleaned.components(separatedBy: characterSet).joined(separator: " ")
        
        // Remove extra spaces
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

// MARK: - Preview

#if DEBUG
struct BatchArtworkMatchingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BatchArtworkMatchingView()
        }
    }
}
#endif

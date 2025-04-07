//
//  GameItemViewRow.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVRealm
import RealmSwift
import PVThemes

@available(iOS 14, tvOS 14, *)
struct GameItemViewRow: SwiftUI.View, Equatable {
    /// Implement Equatable to prevent unnecessary redraws
    static func == (lhs: GameItemViewRow, rhs: GameItemViewRow) -> Bool {
        /// Only redraw if these key properties change
        lhs.game.id == rhs.game.id &&
        lhs.artwork?.hashValue == rhs.artwork?.hashValue &&
        lhs.hoverScale == rhs.hoverScale &&
        lhs.glowIntensity == rhs.glowIntensity
    }
    
    @ObservedRealmObject var game: PVGame
    @Default(.showGameTitles) private var showGameTitles
    
    var artwork: SwiftImage?
    var constrainHeight: Bool = false
    var viewType: GameItemViewType
    
    @State private var textMaxWidth: CGFloat = PVRowHeight
    @State private var hoverScale: CGFloat = 1.0
    @State private var glowIntensity: CGFloat = 0.0
    @State private var isVisible: Bool = false
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var discCount: Int {
        let allFiles = game.relatedFiles.toArray()
        let uniqueFiles = Set(allFiles.compactMap { $0.url?.path })
        return uniqueFiles.count
    }
    
    private var shouldShowDiscIndicator: Bool {
        discCount > 1
    }
    
    private var textColor: Color {
        Color.retroPink
    }
    
    private var glowColor: Color {
        Color.retroPurple
    }
    
    private var secondaryColor: Color {
        Color.retroBlue
    }
    
    var body: some SwiftUI.View {
        if !game.isInvalidated {
            HStack(alignment: .center, spacing: 16) {
                // Game cover image with effects
                ZStack {
                    // Glow effect behind the image
                    if let artwork = artwork, glowIntensity > 0 {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: 8)
                            .opacity(glowIntensity * 0.3)
                            .frame(width: 60, height: 60)
                    }
                    
                    // Main artwork
                    GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
                        .frame(width: 60, height: 60)
                        .scaleEffect(hoverScale)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            glowColor.opacity(0.8),
                                            secondaryColor.opacity(0.8),
                                            glowColor.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .opacity(glowIntensity > 0 ? glowIntensity : 0)
                        )
                        .shadow(color: glowIntensity > 0 ? glowColor.opacity(0.5 * glowIntensity) : .clear,
                                radius: glowIntensity > 0 ? 8 : 0,
                                x: 0, y: 0)
                }
                .overlay(alignment: .topTrailing) {
                    if shouldShowDiscIndicator {
                        DiscIndicatorView(count: discCount)
                            .offset(x: 5, y: -5)
                            .scaleEffect(0.8)
                    }
                }
                
                // Game details
                VStack(alignment: .leading, spacing: 4) {
                    // Title with marquee effect for long titles
                    MarqueeText(text: game.title,
                                font: .system(size: viewType.titleFontSize, weight: .bold, design: .monospaced),
                                delay: 1.0,
                                speed: 50.0,
                                loop: true)
                        .foregroundColor(textColor)
                        .shadow(color: glowColor.opacity(0.7), radius: 2, x: 1, y: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Game metadata row
                    HStack(spacing: 12) {
                        // System name
                        if let system = game.system {
                            Text(system.shortName.uppercased())
                                .font(.system(size: viewType.subtitleFontSize, weight: .semibold, design: .monospaced))
                                .foregroundColor(secondaryColor)
                                .shadow(color: glowColor.opacity(0.5), radius: 1, x: 0, y: 0)
                        }
                        
                        // Release date
                        if let publishDate = game.publishDate {
                            Text(publishDate)
                                .font(.system(size: viewType.subtitleFontSize - 1, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.retroCyan)
                                .shadow(color: glowColor.opacity(0.3), radius: 1, x: 0, y: 0)
                        }
                        
                        Spacer()
                        
                        // Rating stars
                        if game.rating > 0 {
                            Text(String(repeating: "⭐️", count: game.rating))
                                .font(.system(size: viewType.subtitleFontSize - 2))
                                .lineLimit(1)
                        }
                    }
                    
                    // Additional game info row
                    HStack {
                        // Last played date
                        if let lastPlayed = game.lastPlayed {
                            Text("PLAYED: \(lastPlayed.formatted(date: .numeric, time: .shortened))")
                                .font(.system(size: viewType.subtitleFontSize - 2, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.retroCyan.opacity(0.8))
                                .shadow(color: glowColor.opacity(0.3), radius: 1, x: 0, y: 0)
                        }
                        
                        Spacer()
                        
                        // Play count
                        if game.playCount > 0 {
                            Text("\(game.playCount)x")
                                .font(.system(size: viewType.subtitleFontSize - 2, weight: .bold, design: .monospaced))
                                .foregroundColor(secondaryColor.opacity(0.8))
                                .shadow(color: glowColor.opacity(0.3), radius: 1, x: 0, y: 0)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 8)
            .frame(height: 70.0)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.retroBlack.opacity(0.6))
                    
                    // Border gradient
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    glowIntensity > 0 ? glowColor.opacity(0.6) : Color.clear,
                                    glowIntensity > 0 ? secondaryColor.opacity(0.6) : Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .onAppear {
                isVisible = true
            }
            .onDisappear {
                isVisible = false
                // Reset effects when not visible
                if hoverScale != 1.0 {
                    hoverScale = 1.0
                }
                if glowIntensity != 0.0 {
                    glowIntensity = 0.0
                }
            }
            #if !os(tvOS)
            .onHover { hovering in
                // Only animate if the view is visible
                guard isVisible else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoverScale = hovering ? 1.05 : 1.0
                    glowIntensity = hovering ? 1.0 : 0.0
                }
            }
            #endif
        }
    }
}

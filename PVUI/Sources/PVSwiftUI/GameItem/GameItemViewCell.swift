//
//  GameItemViewCell.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVRealm
import RealmSwift
import CoreImage
import CoreImage.CIFilterBuiltins
import PVThemes

struct GameItemViewCell: View {
    @ObservedRealmObject var game: PVGame
    @Default(.showGameTitles) private var showGameTitles
    var artwork: SwiftImage?
    var constrainHeight: Bool = false
    var viewType: GameItemViewType
    @State private var textMaxWidth: CGFloat = PVRowHeight
    @State private var hoverScale: CGFloat = 1.0
    @State private var glowIntensity: CGFloat = 0.0
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var textColor: Color {
        let backgroundColor = themeManager.currentPalette.gameLibraryBackground.swiftUIColor
        return backgroundColor.isDarkColor() ? .white : .black
    }
    
    private var glowColor: Color {
        switch themeManager.currentPalette {
        case is DarkThemePalette:
            return .cyan
        case is LightThemePalette:
            return .blue
        default:
            return .purple
        }
    }
    
    var body: some View {
        if !game.isInvalidated {
            VStack(alignment: .leading, spacing: 3) {
                Spacer(minLength: 0) /// Push content to bottom
                
                ZStack {
                    // Background glow
                    if let artwork = artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: 10)
                            .opacity(glowIntensity * 0.3)
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .clear,
                                        glowColor.opacity(0.3 * glowIntensity),
                                        .clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .blendMode(.screen)
                            )
                    }
                    
                    // Main artwork with effects
                    GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
                        .scaleEffect(hoverScale)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            glowColor.opacity(0.8),
                                            glowColor.complementary().opacity(0.8),
                                            glowColor.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .opacity(glowIntensity)
                        )
                        .shadow(color: glowColor.opacity(0.5 * glowIntensity), radius: 10, x: 0, y: 0)
                    #if !os(tvOS)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoverScale = hovering ? 1.05 : 1.0
                                glowIntensity = hovering ? 1.0 : 0.0
                            }
                        }
                    #endif
                }
                .padding(.bottom, 8) /// Add padding between artwork and text
                
                if showGameTitles {
                    // Title and date container
                    VStack(alignment: .leading, spacing: 0) { /// No spacing between title and date
                        MarqueeText(text: game.title,
                                    font: .system(size: viewType.titleFontSize, weight: .bold, design: .monospaced),
                                    delay: 1.0,
                                    speed: 50.0,
                                    loop: true)
                        .foregroundColor(textColor)
                        .shadow(color: glowColor, radius: 3, x: 0, y: 0)
                        .frame(maxWidth: textMaxWidth, alignment: .leading)
                        .padding(.bottom, -2) /// Negative padding to remove default spacing
                        
                        // Always reserve space for date
                        Text(game.publishDate ?? " ")
                            .font(.system(size: viewType.subtitleFontSize, weight: .medium, design: .monospaced))
                            .foregroundColor(textColor.opacity(0.8))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, -2) /// Negative padding to remove default spacing
                    }
                    .frame(height: viewType.subtitleFontSize + 2) /// Reduced fixed height for text container
                }
            }
            .if(constrainHeight) { view in
                view.frame(height: PVRowHeight, alignment: .bottom)
            }
            .onPreferenceChange(ArtworkDynamicWidthPreferenceKey.self) {
                textMaxWidth = $0
            }
        }
    }
}

extension Color {
    func isDarkColor() -> Bool {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        /// Handle different color spaces safely
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil) {
            let brightness = (red * 299 + green * 587 + blue * 114) / 1000
            return brightness < 0.5
        } else if let components = uiColor.cgColor.components {
            /// Handle grayscale colors
            let brightness = components[0] * (components.count > 1 ? 1.0 : 1.0)
            return brightness < 0.5
        }
        
        /// Default to dark if we can't determine
        return true
    }
    
    func complementary() -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1.0),
                     saturation: saturation,
                     brightness: brightness,
                     opacity: alpha)
    }
}

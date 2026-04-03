import SwiftUI
import PVThemes

struct ContinuesSearchBar: View {
    @Binding var text: String
    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

    // Animation states for theme-aware effects
    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false

    private var currentPalette: any UXThemePalette { themeManager.currentPalette }

    private var primaryTextColor: Color {
        themeManager.currentPalette.gameLibraryText.swiftUIColor
    }

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor
    }

    private var searchBackgroundColor: Color {
        if let cellBg = themeManager.currentPalette.settingsCellBackground {
            return cellBg.swiftUIColor.opacity(themeManager.currentPalette.dark ? 0.7 : 0.9)
        }
        return themeManager.currentPalette.dark
            ? Color.black.opacity(0.7)
            : Color.white.opacity(0.9)
    }

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isFocused ? accentColor : Color.gray.opacity(0.7))
                    .font(.system(size: 16))
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .shadow(color: isFocused ? accentColor.opacity(glowOpacity) : .clear, radius: 2, x: 0, y: 0)

                TextField("SEARCH SAVES", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .foregroundColor(primaryTextColor)
                    .font(.system(size: 14, weight: .medium))

                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(accentColor)
                            .font(.system(size: 16))
                            .shadow(color: accentColor.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: RetroPauseChrome.searchFieldCornerRadius())
                    .fill(searchBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: RetroPauseChrome.searchFieldCornerRadius())
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [accentColor, accentColor.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isFocused || isHovered ? 2.0 : 1.5
                            )
                    )
                    .shadow(color: isFocused ? accentColor.opacity(glowOpacity) : accentColor.opacity(glowOpacity * 0.5),
                            radius: isFocused || isHovered ? 5 : 3,
                            x: 0,
                            y: 0)
            )
        }
        #if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
        .onAppear {
            // Start animations
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

#Preview("focused") {
    ContinuesSearchBar(text: .constant("Test"))
}

#Preview("not focused") {
    ContinuesSearchBar(text: .constant(""))
}

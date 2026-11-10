import SwiftUI
import PVThemes

struct ContinuesSearchBar: View {
    @Binding var text: String
    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

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

                TextField("Search saves", text: $text)
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
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: RetroPauseChrome.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: RetroPauseChrome.searchFieldCornerRadius())
                    .fill(searchBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: RetroPauseChrome.searchFieldCornerRadius())
                            .strokeBorder(isFocused || isHovered ? accentColor : RetroPauseChrome.chromeBorder)
                    )
            )
        }
        #if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

#Preview("focused") {
    ContinuesSearchBar(text: .constant("Test"))
}

#Preview("not focused") {
    ContinuesSearchBar(text: .constant(""))
}

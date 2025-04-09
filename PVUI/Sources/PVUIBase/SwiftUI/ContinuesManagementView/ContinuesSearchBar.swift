import SwiftUI
import PVThemes

struct ContinuesSearchBar: View {
    @Binding var text: String
    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false
    
    private var currentPalette: any UXThemePalette { themeManager.currentPalette }
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isFocused ? RetroTheme.retroPink : Color.gray.opacity(0.7))
                    .font(.system(size: 16))
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .shadow(color: isFocused ? RetroTheme.retroPink.opacity(glowOpacity) : .clear, radius: 2, x: 0, y: 0)
                
                TextField("SEARCH SAVES", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(RetroTheme.retroPurple)
                            .font(.system(size: 16))
                            .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(RetroTheme.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isFocused || isHovered ? 2.0 : 1.5
                            )
                    )
                    .shadow(color: isFocused ? RetroTheme.retroPink.opacity(glowOpacity) : RetroTheme.retroPurple.opacity(glowOpacity * 0.5), 
                            radius: isFocused || isHovered ? 5 : 3, 
                            x: 0, 
                            y: 0)
            )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
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

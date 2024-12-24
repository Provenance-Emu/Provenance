import SwiftUI
import PVSwiftUI
import PVThemes

struct ContinuesSearchBar: View {
    @Binding var text: String
    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool
    
    private var currentPalette: any UXThemePalette { themeManager.currentPalette }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(currentPalette.settingsCellText?.swiftUIColor ?? .gray)
            
            TextField("Search", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .foregroundColor(currentPalette.settingsCellText?.swiftUIColor)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(currentPalette.settingsCellText?.swiftUIColor ?? .gray)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
            #if os(tvOS)
                .fill(currentPalette.settingsHeaderBackground?.swiftUIColor ?? .gray)
            #else
                .fill(currentPalette.settingsHeaderBackground?.swiftUIColor ?? Color(.systemGray6))
            #endif
        )
    }
}

#Preview("focused") {
    ContinuesSearchBar(text: .constant("Test"))
}

#Preview("not focused") {
    ContinuesSearchBar(text: .constant(""))
}

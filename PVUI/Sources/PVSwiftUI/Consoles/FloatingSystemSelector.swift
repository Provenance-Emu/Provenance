import SwiftUI
import PVUIBase
import PVThemes

#if os(iOS)
struct FloatingSystemSelectorItem: Identifiable {
    let id: String
    let title: String
    let icon: Image
}

/// One row of system shortcuts. The active system follows page and sidebar navigation.
struct FloatingSystemSelector: View {
    let items: [FloatingSystemSelectorItem]
    @Binding var selection: String
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let edgeFade: CGFloat = 12
    private static let minItemWidth: CGFloat = 48

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 2) {
                    ForEach(items) { item in
                        systemButton(item)
                    }
                }
                .padding(.horizontal, Self.edgeFade)
            }
            // Items fade out at the ends instead of being cut by the rounded corners.
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: Self.edgeFade)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: Self.edgeFade)
                }
            }
            .onChange(of: selection, initial: true) { _, value in
                if reduceMotion {
                    proxy.scrollTo(value, anchor: .center)
                } else {
                    withAnimation { proxy.scrollTo(value, anchor: .center) }
                }
            }
            .onChange(of: items.map(\.id)) { _, _ in
                proxy.scrollTo(selection, anchor: .center)
            }
        }
        .frame(height: LibraryLayout.controlHeight)
        .libraryDockChrome()
        .padding(.horizontal, LibraryLayout.chromeHorizontalInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Systems")
    }

    private func systemButton(_ item: FloatingSystemSelectorItem) -> some View {
        let isSelected = selection == item.id
        let textColor = Color(themeManager.currentPalette.gameLibraryText)
        return Button {
            selection = item.id
        } label: {
            VStack(spacing: 1) {
                item.icon.resizable().renderingMode(.template).scaledToFit()
                    .frame(width: 25, height: 18)
                    .foregroundStyle(isSelected ? Color.retroBlue : textColor.opacity(0.65))
                // Semibold in both states so selecting a system never changes the item's width.
                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(textColor.opacity(isSelected ? 1 : 0.82))
            }
            .padding(.horizontal, 7)
            .frame(minWidth: Self.minItemWidth)
            .frame(height: 34)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.retroBlue.opacity(0.12))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(LibraryLayout.chromeBorder) }
                }
            }
            .frame(height: LibraryLayout.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(item.title)
        .id(item.id)
    }
}
#endif

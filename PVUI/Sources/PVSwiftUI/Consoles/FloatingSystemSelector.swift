import SwiftUI
import PVUIBase
import PVThemes

#if os(iOS)
struct FloatingSystemSelectorItem: Identifiable {
    let id: String
    let title: String
    let icon: Image
}

/// Borderless console shortcuts with one composite glow along the actual vector edges.
struct FloatingSystemSelector: View {
    let items: [FloatingSystemSelectorItem]
    @Binding var selection: String
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ViewThatFits(in: .horizontal) {
            icons.fixedSize(horizontal: true, vertical: false)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { icons }
                    .onAppear { proxy.scrollTo(selection, anchor: .center) }
                    .onChange(of: selection) { _, value in
                        if reduceMotion {
                            proxy.scrollTo(value, anchor: .center)
                        } else {
                            withAnimation { proxy.scrollTo(value, anchor: .center) }
                        }
                    }
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    private var icons: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    VStack(spacing: 2) {
                        item.icon.resizable().renderingMode(.template).scaledToFit()
                            .frame(width: 32, height: 24)
                            .foregroundStyle(selection == item.id ? Color.retroBlue : Color(themeManager.currentPalette.gameLibraryText).opacity(0.5))
                            .shadow(color: selection == item.id ? Color.retroBlue.opacity(0.3) : .clear, radius: 1.5)
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(selection == item.id ? 1 : 0.7))
                    }
                    .frame(width: 56, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item.id ? .isSelected : [])
                .help(item.title)
                .id(item.id)
            }
        }
    }

}
#endif

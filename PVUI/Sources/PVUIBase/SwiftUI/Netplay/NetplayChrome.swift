import SwiftUI
import PVThemes

#if !os(watchOS)
/// An opaque, palette-aware surface for every step of the network-play flow.
private struct NetplayScreenModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        let palette = themeManager.currentPalette
        content
            #if !os(tvOS)
            .scrollContentBackground(.hidden)
            #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    palette.dark ? Color.black : Color.white
                    Color(palette.gameLibraryBackground)
                    RetroGrid()
                        .opacity(palette.dark ? 0.08 : 0.03)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
            .tint(Color(palette.defaultTintColor))
            .environment(\.colorScheme, palette.dark ? .dark : .light)
            .preferredColorScheme(palette.dark ? .dark : .light)
            #if canImport(UIKit)
            .toolbarBackground(Color(palette.gameLibraryBackground), for: .navigationBar)
            .toolbarColorScheme(palette.dark ? .dark : .light, for: .navigationBar)
            #endif
    }
}

private struct NetplayTitleModifier: ViewModifier {
    let title: LocalizedStringKey
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content.navigationTitle(Text(title))
            #if os(tvOS)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(Color(themeManager.currentPalette.navigationBarTitleColor ?? themeManager.currentPalette.gameLibraryCellText))
                }
            }
            #endif
    }
}

extension View {
    func netplayScreen() -> some View {
        modifier(NetplayScreenModifier())
    }

    func netplayNavigationTitle(_ title: LocalizedStringKey) -> some View {
        modifier(NetplayTitleModifier(title: title))
    }

    /// TV forms need the full display; compact sheets remain appropriate on iOS.
    @ViewBuilder
    public func netplayPresentation<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(tvOS)
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
            content().onExitCommand { isPresented.wrappedValue = false }
        }
        #else
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    @ViewBuilder
    public func netplayPresentation<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(tvOS)
        fullScreenCover(item: item, onDismiss: onDismiss) { value in
            content(value).onExitCommand { item.wrappedValue = nil }
        }
        #else
        sheet(item: item, onDismiss: onDismiss, content: content)
        #endif
    }
}

/// Shared form layout with room for TV focus rings and readable sections on phones.
struct NetplayForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                content
            }
            .padding(.vertical, 28)
            .padding(.horizontal, horizontalInset)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        #if os(tvOS)
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 64) }
        #endif
        .toggleStyle(NetplayToggleStyle())
        .netplayScreen()
    }

    private var horizontalInset: CGFloat {
        #if os(tvOS)
        64
        #else
        20
        #endif
    }
}

/// A focusable disclosure on TV, where SwiftUI's DisclosureGroup is unavailable.
struct NetplayDisclosure<Content: View>: View {
    let title: LocalizedStringKey
    let externalExpansion: Binding<Bool>?
    @ViewBuilder let content: Content
    @State private var expanded = false

    init(_ title: LocalizedStringKey, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        externalExpansion = isExpanded
        self.content = content()
    }

    private var expansion: Binding<Bool> { externalExpansion ?? $expanded }

    var body: some View {
        #if os(tvOS)
        VStack(alignment: .leading, spacing: 20) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expansion.wrappedValue.toggle() }
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: expansion.wrappedValue ? "chevron.up" : "chevron.down")
                }.padding(16)
            }
            .retroFocusButtonStyle(focusScale: 1.025)
            .accessibilityValue(expansion.wrappedValue ? "Expanded" : "Collapsed")
            if expansion.wrappedValue { content }
        }
        #else
        DisclosureGroup(title, isExpanded: expansion) { content }
        #endif
    }
}

/// Keeps the setting label visible outside a system Form, including on Apple TV.
private struct NetplayToggleStyle: ToggleStyle {
    @ObservedObject private var themeManager = ThemeManager.shared

    func makeBody(configuration: Configuration) -> some View {
        #if os(tvOS)
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryCellText))
                Spacer()
                Label(configuration.isOn ? "On" : "Off", systemImage: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color(themeManager.currentPalette.defaultTintColor))
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(themeManager.currentPalette.defaultTintColor).opacity(configuration.isOn ? 0.14 : 0.04))
            }
        }
        .retroFocusButtonStyle(focusScale: 1.025)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        #else
        Toggle(isOn: configuration.$isOn) { configuration.label }
            .toggleStyle(.switch)
        #endif
    }
}

/// A themed card rather than a platform-default list section.
struct NetplayFormSection<Content: View, Header: View, Footer: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let content: Content
    let header: Header
    let footer: Footer

    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .font(.headline)
                .foregroundStyle(Color(themeManager.currentPalette.defaultTintColor))
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(themeManager.currentPalette.gameLibraryHeaderBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color(themeManager.currentPalette.defaultTintColor).opacity(0.25), lineWidth: 1)
                    }
            }
            footer
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

extension NetplayFormSection where Header == Text, Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { Text(title) }, footer: { EmptyView() })
    }
}

extension NetplayFormSection where Header == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, header: { EmptyView() }, footer: { EmptyView() })
    }
}

extension NetplayFormSection where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.init(content: content, header: header, footer: { EmptyView() })
    }
}

extension NetplayFormSection where Header == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(content: content, header: { EmptyView() }, footer: footer)
    }
}

/// A large action target using the same focus treatment as the rest of Provenance.
struct NetplayActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var color: Color = .retroPink
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right").foregroundStyle(color)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryCellText))
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(themeManager.currentPalette.gameLibraryHeaderBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(color.opacity(0.4), lineWidth: 1)
                    }
            }
        }
        .retroFocusButtonStyle(focusScale: 1.025, cornerRadius: 18)
    }
}
#endif

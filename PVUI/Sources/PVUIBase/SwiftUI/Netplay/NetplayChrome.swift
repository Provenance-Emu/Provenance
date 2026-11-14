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
            #if os(tvOS)
            // TV forms scroll under the title; an opaque bar keeps both readable.
            .toolbarBackground(.visible, for: .navigationBar)
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

/// Closes the netplay screens and resumes the game they were opened over. Set by whoever
/// presents them from a paused game; nil in the library, where there is no game to return to.
struct NetplayReturnToGameAction {
    let perform: @MainActor () -> Void

    @MainActor
    func callAsFunction() { perform() }
}

/// What a successful join from the in-game screens does: say so, then go back to the game.
@MainActor
enum NetplayJoinFeedback {
    static func joined(_ hostName: String, returnToGame: NetplayReturnToGameAction?, dismiss: DismissAction) {
        PVToastManager.post(String(localized: "Joined \(hostName)."), type: .success, icon: "antenna.radiowaves.left.and.right")
        if let returnToGame { returnToGame() } else { dismiss() }
    }
}

private struct NetplayReturnToGameKey: EnvironmentKey {
    static var defaultValue: NetplayReturnToGameAction? { nil }
}

extension EnvironmentValues {
    var netplayReturnToGame: NetplayReturnToGameAction? {
        get { self[NetplayReturnToGameKey.self] }
        set { self[NetplayReturnToGameKey.self] = newValue }
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

/// A choice among a few values (a list filter, a play style): a plain button that touch, the
/// tvOS focus engine and the iOS controller cursor all drive. Selection and focus have
/// separate colors so both stay readable on a TV.
struct NetplayChoiceChip: View {
    let title: String
    let selected: Bool
    /// The iOS controller cursor is on this chip.
    var isCursor = false
    let action: () -> Void
    @FocusState private var focused: Bool
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        let accent = Color(themeManager.currentPalette.defaultTintColor)
        let lit = focused || isCursor
        Button(action: action) {
            Text(title)
                .font(chipFont)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, verticalPadding)
                .foregroundStyle(lit ? Color.black : Color(themeManager.currentPalette.gameLibraryCellText))
                .background(lit ? Color.white : accent.opacity(selected ? 0.3 : 0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? accent : .clear, lineWidth: 3)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .focused($focused)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var chipFont: Font {
        #if os(tvOS)
        .system(size: 25, weight: .semibold)
        #else
        .subheadline.weight(.semibold)
        #endif
    }

    private var verticalPadding: CGFloat {
        #if os(tvOS)
        18
        #else
        10
        #endif
    }
}

/// A row of `NetplayChoiceChip`s for picking one value, in place of a `Picker` (which a
/// controller cannot drive on iOS and which pushes a separate list on tvOS).
struct NetplayChoiceRow<Value: Hashable>: View {
    let title: String
    let choices: [(value: Value, title: String)]
    @Binding var selection: Value
    /// The cursor ID prefix: each chip is `"<cursorPrefix>.<index>"`.
    let cursorPrefix: String
    let cursor: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
            // Too many choices for the width (a phone): scroll them sideways rather than truncate.
            // Chips keep their full width in both, or the first always "fits" by truncating.
            ViewThatFits(in: .horizontal) {
                chips
                ScrollView(.horizontal, showsIndicators: false) {
                    chips
                        .padding(.vertical, NetplayCursorMetrics.highlightOutset)
                        .padding(.horizontal, NetplayCursorMetrics.highlightOutset)
                }
            }
        }
    }

    private var chips: some View {
        HStack(spacing: 10) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                let id = Self.cursorID(cursorPrefix, index)
                NetplayChoiceChip(title: choice.title, selected: choice.value == selection, isCursor: cursor == id) {
                    selection = choice.value
                }
                .fixedSize(horizontal: true, vertical: false)
                .netplayCursorItem(id, cursor: cursor, cornerRadius: 16)
            }
        }
    }

    static func cursorID(_ prefix: String, _ index: Int) -> String { "\(prefix).\(index)" }

    /// The cursor row matching this view.
    static func cursorRow(_ prefix: String, choices: [Value], selection: Binding<Value>, isHeader: Bool = true) -> NetplayCursorRow {
        NetplayCursorRow(id: "row.\(prefix)", isHeader: isHeader, targets: choices.enumerated().map { index, value in
            NetplayCursorTarget(id: cursorID(prefix, index)) { selection.wrappedValue = value }
        })
    }
}

/// Shared form layout with room for TV focus rings and readable sections on phones.
struct NetplayForm<Content: View>: View {
    /// The `.id` of a field to bring into view, set while it is being edited: the keyboard
    /// otherwise covers a field near the bottom of a sheet.
    var scrollTarget: String?
    @ViewBuilder let content: Content

    /// Long enough for the keyboard to finish sliding in, so the scroll lands above it.
    private static var keyboardSettleDelay: Duration { .milliseconds(350) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    content
                }
                .padding(.vertical, 28)
                .padding(.horizontal, horizontalInset)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .task(id: scrollTarget) {
                guard let scrollTarget else { return }
                try? await Task.sleep(for: Self.keyboardSettleDelay)
                guard !Task.isCancelled else { return }
                withAnimation { proxy.scrollTo(scrollTarget, anchor: .center) }
            }
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

/// A disclosure built from a plain button, so the TV focus engine and the iOS controller
/// cursor can open it (SwiftUI's DisclosureGroup is unavailable on TV and cannot be pressed
/// from code on iOS). A screen that lists it as a cursor target passes `isExpanded`, `cursorID`
/// and `cursor`.
struct NetplayDisclosure<Content: View>: View {
    let title: LocalizedStringKey
    let externalExpansion: Binding<Bool>?
    let cursorID: String?
    let cursor: String?
    @ViewBuilder let content: Content
    @State private var expanded = false

    init(_ title: LocalizedStringKey, isExpanded: Binding<Bool>? = nil, cursorID: String? = nil, cursor: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        externalExpansion = isExpanded
        self.cursorID = cursorID
        self.cursor = cursor
        self.content = content()
    }

    private var expansion: Binding<Bool> { externalExpansion ?? $expanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expansion.wrappedValue.toggle() }
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: expansion.wrappedValue ? "chevron.up" : "chevron.down")
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .retroFocusButtonStyle(focusScale: 1.025)
            .netplayCursorItem(cursorID, cursor: cursor)
            .accessibilityValue(expansion.wrappedValue ? "Expanded" : "Collapsed")
            if expansion.wrappedValue { content }
        }
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

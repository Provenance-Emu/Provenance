//
//  SettingsSidebarContainer.swift
//  PVUI
//
//  iOS Settings root, after iFly's settings layout: a sidebar of panes beside the selected pane's content
//  when the container is wide enough, a capsule tab strip above it otherwise (`SettingsLayoutRules`).
//  The pane content itself is supplied by `PVSettingsView`, which owns the (file-private) section views.
//  tvOS keeps its own layout and never uses this file.
//

#if !os(tvOS)
import SwiftUI
import PVThemes
import PVUIBase

struct SettingsSidebarContainer<PaneContent: View>: View {
    @Binding private var selectedPane: SettingsPane
    @Binding private var searchQuery: String
    private let searchFocused: FocusState<Bool>.Binding
    /// Section picked from search; scrolled to (and cleared) once its pane is on screen.
    @Binding private var pendingScrollSection: String?
    /// `nil` hides the Done / Help header row (Settings embedded rather than presented).
    private let onDone: (() -> Void)?
    private let onHelp: (() -> Void)?
    private let onSelectSearchResult: (SettingsSearchEntry) -> Void
    private let paneContent: (SettingsPane) -> PaneContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var themeManager = ThemeManager.shared

    init(
        selectedPane: Binding<SettingsPane>,
        searchQuery: Binding<String>,
        searchFocused: FocusState<Bool>.Binding,
        pendingScrollSection: Binding<String?>,
        onDone: (() -> Void)?,
        onHelp: (() -> Void)?,
        onSelectSearchResult: @escaping (SettingsSearchEntry) -> Void,
        @ViewBuilder paneContent: @escaping (SettingsPane) -> PaneContent
    ) {
        _selectedPane = selectedPane
        _searchQuery = searchQuery
        self.searchFocused = searchFocused
        _pendingScrollSection = pendingScrollSection
        self.onDone = onDone
        self.onHelp = onHelp
        self.onSelectSearchResult = onSelectSearchResult
        self.paneContent = paneContent
    }

    private var widthClass: SettingsWidthClass {
        switch horizontalSizeClass {
        case .regular: return .regular
        case .compact: return .compact
        default: return .unknown
        }
    }

    private var textColor: Color {
        Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText)
    }

    private var surfaceColor: Color {
        Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground)
    }

    private var isSearching: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= SettingsSearchIndex.minimumQueryLength
    }

    var body: some View {
        VStack(spacing: 0) {
            if onDone != nil || onHelp != nil {
                headerRow
            }
            // A concrete container width on every pass decides the arrangement and sizes the column.
            GeometryReader { geometry in
                let arrangement = SettingsLayoutRules.arrangement(
                    platform: .current,
                    widthClass: widthClass,
                    containerWidth: geometry.size.width
                )
                if arrangement == .sidebar {
                    HStack(spacing: 0) {
                        sidebar
                        Rectangle()
                            .fill(Color.retroPurple.opacity(0.4))
                            .frame(width: 1)
                        contentPane(capsColumn: true)
                    }
                } else {
                    VStack(spacing: 0) {
                        tabStrip
                        contentPane(capsColumn: false)
                    }
                }
            }
        }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack {
            if let onDone {
                Button(action: onDone) {
                    Text("settings.done", bundle: .module)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.retroPink)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("settings.title", bundle: .module)
                .font(.headline)
                .foregroundColor(textColor)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let onHelp {
                Button(action: onHelp) {
                    Text("settings.help", bundle: .module)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.retroBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(surfaceColor.opacity(0.6))
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.retroPink, .retroPurple, .retroBlue], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .opacity(0.6)
        }
    }

    // MARK: Sidebar (regular)

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsPane.allCases) { pane in
                    Button {
                        select(pane)
                    } label: {
                        sidebarLabel(pane)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedPane == pane ? .isSelected : [])
                }
            }
            .padding(8)
        }
        .frame(width: SettingsLayoutRules.sidebarWidth)
        .background(surfaceColor.opacity(0.5))
    }

    private func sidebarLabel(_ pane: SettingsPane) -> some View {
        let isSelected = selectedPane == pane
        return HStack(spacing: 8) {
            Image(systemName: pane.icon)
                .font(.system(size: 17))
                .frame(width: 22)
            Text(pane.title)
                .font(.system(.callout, design: .monospaced).weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundColor(isSelected ? .retroPink : textColor)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.retroPink.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    // MARK: Tab strip (compact)

    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SettingsPane.allCases) { pane in
                        Button {
                            select(pane)
                        } label: {
                            tabChip(pane)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedPane == pane ? .isSelected : [])
                        .id(pane)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            .onAppear { proxy.scrollTo(selectedPane, anchor: .center) }
            .onChange(of: selectedPane) { _, pane in
                withAnimation { proxy.scrollTo(pane, anchor: .center) }
            }
        }
    }

    private func tabChip(_ pane: SettingsPane) -> some View {
        let isSelected = selectedPane == pane
        return HStack(spacing: 5) {
            Image(systemName: pane.icon)
                .font(.caption)
            Text(pane.title)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundColor(isSelected ? .white : textColor)
        // Purple, not pink, under the white label: retroPink is too light for 12pt white text.
        .background(
            Capsule().fill(isSelected ? AnyShapeStyle(Color.retroPurple) : AnyShapeStyle(.ultraThinMaterial))
        )
        .overlay(
            Capsule().strokeBorder(isSelected ? Color.retroPink : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Capsule())
    }

    // MARK: Content

    private func contentPane(capsColumn: Bool) -> some View {
        VStack(spacing: 0) {
            SettingsSearchField(text: $searchQuery, isFocused: searchFocused)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if isSearching {
                SettingsSearchResultsView(query: searchQuery, onSelect: onSelectSearchResult)
            } else {
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            column(containerWidth: geometry.size.width, capsColumn: capsColumn)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        // Runs when the pane's scroll view appears (new pane, or the results list just closed
                        // on the same pane) and whenever a new section is requested.
                        .task(id: pendingScrollSection) {
                            guard let section = pendingScrollSection else { return }
                            await Task.yield()
                            withAnimation {
                                proxy.scrollTo(section, anchor: .top)
                            }
                            pendingScrollSection = nil
                        }
                    }
                }
                // Each pane starts at the top instead of inheriting the previous pane's offset.
                .id(selectedPane)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Near-opaque so the retro grid does not sit behind body text; it stays visible around the content.
        .background(Color(themeManager.currentPalette.gameLibraryBackground).opacity(0.92))
    }

    @ViewBuilder
    private func column(containerWidth: CGFloat, capsColumn: Bool) -> some View {
        let column = VStack(alignment: .leading, spacing: 24) {
            paneContent(selectedPane)
        }
        .padding()

        if capsColumn {
            column
                .frame(maxWidth: SettingsLayoutRules.contentMaxWidth, alignment: .leading)
                .frame(width: max(0, containerWidth), alignment: .center)
        } else {
            column.frame(width: max(0, containerWidth), alignment: .leading)
        }
    }

    private func select(_ pane: SettingsPane) {
        searchFocused.wrappedValue = false
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedPane = pane
        }
    }
}

// MARK: - Pane section

/// One settings section inside a pane: a plain, always-expanded header in iFly's type scale over a card of rows.
/// The section title is also the scroll anchor that settings search jumps to.
struct SettingsPaneSection<Content: View>: View {
    private let title: String
    private let content: Content

    @ObservedObject private var themeManager = ThemeManager.shared

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    private var cardColor: Color {
        Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.retroPink)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardColor.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.3), Color.retroBlue.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .id(title)
    }
}
#endif

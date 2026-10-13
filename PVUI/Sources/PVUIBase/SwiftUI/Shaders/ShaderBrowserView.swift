//
//  ShaderBrowserView.swift
//  PVUI
//
//  Searchable, grouped list of every filter: Provenance's own filters plus the
//  bundled slang library. Used by Settings and the pause menu.
//

import SwiftUI
import PVShaders
import PVThemes

/// A choice the browser can report.
public enum ShaderBrowserChoice: Hashable {
    case off
    /// The current skin's own CIFilter.
    case skinFilter
    case shader(ShaderID)

    public init(_ selection: ShaderSelection) {
        switch selection {
        case .off, .auto: self = .off
        case .skinFilter: self = .skinFilter
        case .always(let id): self = .shader(id)
        }
    }

    public var selection: ShaderSelection {
        switch self {
        case .off: return .off
        case .skinFilter: return .skinFilter
        case .shader(let id): return .always(id)
        }
    }
}

public struct ShaderBrowserView: View {
    /// The choice to mark as current.
    let current: ShaderBrowserChoice?
    /// Offer "Skin's filter" (only when the current skin ships one).
    let showsSkinFilter: Bool
    let onSelect: (ShaderBrowserChoice) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var query = ""
    @State private var looks: Set<ShaderLook> = []
    @State private var expandedCategories: Set<String> = [ShaderCatalog.nativeCategory]
    @State private var editing: ShaderCatalogEntry?

    private let store = ShaderLibraryStore.shared
    private let catalog = ShaderCatalog.shared

    public init(current: ShaderBrowserChoice?, showsSkinFilter: Bool = false,
                onSelect: @escaping (ShaderBrowserChoice) -> Void) {
        self.current = current
        self.showsSkinFilter = showsSkinFilter
        self.onSelect = onSelect
    }

    private var palette: UXThemePalette { themeManager.currentPalette }
    private var isFiltering: Bool { !query.isEmpty || !looks.isEmpty }

    public var body: some View {
        List {
            lookChips
            if isFiltering {
                searchResults
            } else {
                SwiftUI.Section {
                    choiceRow(title: String(localized: "Off"), systemImage: "nosign", choice: .off)
                    if showsSkinFilter {
                        choiceRow(title: String(localized: "Skin's Filter"), systemImage: "paintpalette", choice: .skinFilter)
                    }
                }
                listSection(String(localized: "Favorites"), entries: store.favoriteIDs.compactMap(catalog.entry(for:)))
                listSection(String(localized: "Recent"), entries: store.recents.compactMap(catalog.entry(for:)))
                ForEach(catalog.categories, id: \.self) { category in
                    categorySection(category)
                }
            }
        }
        .searchable(text: $query, prompt: Text(String(localized: "Search \(catalog.entries.count) filters")))
        .navigationDestination(item: $editing) { entry in
            ShaderParameterEditorView(entry: entry)
        }
        .onAppear(perform: expandCurrentCategory)
    }

    // MARK: - Sections

    private var lookChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShaderLook.allCases) { look in
                    let isOn = looks.contains(look)
                    Button {
                        if isOn { looks.remove(look) } else { looks.insert(look) }
                    } label: {
                        Text(look.title)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(isOn ? palette.defaultTintColor.swiftUIColor : Color.secondary.opacity(0.2)))
                            .foregroundColor(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = catalog.search(query, looks: looks)
        if results.isEmpty {
            Text(String(localized: "No filters match."))
                .foregroundColor(.secondary)
        } else {
            let grouped = Dictionary(grouping: results, by: \.category)
            ForEach(catalog.categories.filter { grouped[$0] != nil }, id: \.self) { category in
                listSection(ShaderCatalog.categoryTitle(category), entries: grouped[category] ?? [])
            }
        }
    }

    @ViewBuilder
    private func listSection(_ title: String, entries: [ShaderCatalogEntry]) -> some View {
        if !entries.isEmpty {
            SwiftUI.Section(header: Text(title)) {
                ForEach(entries) { entry in row(entry) }
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ category: String) -> some View {
        let entries = catalog.entries.filter { $0.category == category }
        let isExpanded = expandedCategories.contains(category)
        SwiftUI.Section {
            Button {
                if isExpanded { expandedCategories.remove(category) } else { expandedCategories.insert(category) }
            } label: {
                HStack {
                    Text(ShaderCatalog.categoryTitle(category)).font(.headline)
                    Spacer()
                    Text("\(entries.count)").foregroundColor(.secondary).monospacedDigit()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                ForEach(entries) { entry in row(entry) }
            }
        }
    }

    // MARK: - Rows

    private func choiceRow(title: String, systemImage: String, choice: ShaderBrowserChoice) -> some View {
        Button {
            onSelect(choice)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if current == choice {
                    Image(systemName: "checkmark").foregroundColor(palette.defaultTintColor.swiftUIColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ entry: ShaderCatalogEntry) -> some View {
        ShaderRow(entry: entry,
                  isSelected: current == .shader(entry.id),
                  isFavorite: store.isFavorite(entry.id),
                  palette: palette,
                  onSelect: { onSelect(.shader(entry.id)) },
                  onToggleFavorite: { store.toggleFavorite(entry.id) },
                  onEdit: entry.editableParameters.isEmpty ? nil : { editing = entry })
    }

    private func expandCurrentCategory() {
        if case .shader(let id) = current, let entry = catalog.entry(for: id) {
            expandedCategories.insert(entry.category)
        }
    }
}

/// One filter in the browser.
struct ShaderRow: View {
    let entry: ShaderCatalogEntry
    let isSelected: Bool
    let isFavorite: Bool
    let palette: UXThemePalette
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onEdit: (() -> Void)?

    private static let thumbnailSize = CGSize(width: 64, height: 48)

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ShaderThumbnailView(entry: entry, size: Self.thumbnailSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if isFavorite {
                    Image(systemName: "star.fill").foregroundColor(.yellow).imageScale(.small)
                }
                if isSelected {
                    Image(systemName: "checkmark").foregroundColor(palette.defaultTintColor.swiftUIColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onToggleFavorite) {
                Label(isFavorite ? String(localized: "Remove from Favorites") : String(localized: "Add to Favorites"),
                      systemImage: isFavorite ? "star.slash" : "star")
            }
            if let onEdit {
                Button(action: onEdit) {
                    Label(String(localized: "Adjust Parameters"), systemImage: "slider.horizontal.3")
                }
            }
        }
        #if !os(tvOS)
        .swipeActions(edge: .trailing) {
            Button(action: onToggleFavorite) {
                Label(String(localized: "Favorite"), systemImage: isFavorite ? "star.slash" : "star")
            }
            .tint(.yellow)
            if let onEdit {
                Button(action: onEdit) {
                    Label(String(localized: "Adjust"), systemImage: "slider.horizontal.3")
                }
                .tint(palette.defaultTintColor.swiftUIColor)
            }
        }
        #endif
    }

    private var subtitle: String {
        var parts = [ShaderCatalog.categoryTitle(entry.category)]
        if entry.passes > 1 { parts.append(String(localized: "\(entry.passes) passes")) }
        if entry.isHeavy { parts.append(String(localized: "Heavy")) }
        let count = entry.editableParameters.count
        if count > 0 { parts.append(String(localized: "\(count) settings")) }
        return parts.joined(separator: " · ")
    }
}

//
//  SettingsSearchViews.swift
//  PVUI
//
//  Views for searching Settings: an inline themed field + results list on iOS, and a pushed
//  `.searchable` page on tvOS. Both read from `SettingsSearchIndex`.
//

import SwiftUI
import PVThemes
import PVUIBase

#if !os(tvOS)
/// Compact retrowave text field. Not `.searchable`: the settings root has no system navigation bar.
struct SettingsSearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    @ObservedObject private var themeManager = ThemeManager.shared

    private var textColor: Color {
        Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText)
    }

    private var fieldBackground: Color {
        Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            TextField("Search settings", text: $text)
                .focused(isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundColor(textColor)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(fieldBackground.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
}

/// Replaces the tab content while a search query is active.
struct SettingsSearchResultsView: View {
    let query: String
    let onSelect: (SettingsSearchEntry) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private var detailColor: Color {
        Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.gameLibraryText)
    }

    var body: some View {
        let results = SettingsSearchIndex.search(query).filter { $0.isVisible(isAppStore: AppState.shared.isAppStore) }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if results.isEmpty {
                    Text("No settings match")
                        .font(.body)
                        .foregroundColor(detailColor.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    ForEach(results) { entry in
                        Button {
                            onSelect(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                SettingsRow(title: entry.title, subtitle: entry.subtitle)
                                Text("\(entry.tab.title) › \(entry.section)")
                                    .font(.caption2)
                                    .foregroundColor(.retroBlue)
                                    .padding(.leading, 4)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}
#endif

#if os(tvOS)
/// Pushed search page for tvOS (the system keyboard is shown by `.searchable`). Choosing a result reports it to
/// the settings root and pops back; the root then expands, scrolls to and focuses the matching section.
struct TVOSSettingsSearchView: View {
    let onSelect: (SettingsSearchEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let results = SettingsSearchIndex.search(query).filter { $0.isVisible(isAppStore: AppState.shared.isAppStore) }
        let hasQuery = query.trimmingCharacters(in: .whitespaces).count >= SettingsSearchIndex.minimumQueryLength
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if results.isEmpty, hasQuery {
                    Text("No settings match")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.top, 40)
                }
                ForEach(results) { entry in
                    Button {
                        onSelect(entry)
                        dismiss()
                    } label: {
                        SettingsRow(
                            title: entry.title,
                            subtitle: entry.tvOSSection,
                            icon: .sfSymbol("magnifyingglass")
                        )
                    }
                    .retroFocusButtonStyle(showBorder: false)
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 24)
        }
        .searchable(text: $query, prompt: "Search settings")
        .navigationTitle("Search Settings")
        .settingsSubpageTracking()
    }
}
#endif

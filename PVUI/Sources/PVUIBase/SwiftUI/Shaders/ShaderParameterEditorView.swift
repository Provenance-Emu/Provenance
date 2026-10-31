//
//  ShaderParameterEditorView.swift
//  PVUI
//
//  Edits one filter's parameters: grouped sections, search for presets with
//  many settings, per-parameter and full reset, and a live preview.
//

import SwiftUI
import PVShaders
import PVThemes

public struct ShaderParameterEditorView: View {
    let entry: ShaderCatalogEntry
    /// Called after every change, so a paused game can redraw with the new values.
    var onChange: (() -> Void)?

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var query = ""
    private let store = ShaderLibraryStore.shared

    /// Presets with more settings than this get a search field.
    private static let searchThreshold = 12
    private static let previewSize = CGSize(width: 320, height: 240)

    public init(entry: ShaderCatalogEntry, onChange: (() -> Void)? = nil) {
        self.entry = entry
        self.onChange = onChange
    }

    private var palette: UXThemePalette { themeManager.currentPalette }

    private var groups: [ShaderParameterGroup] {
        let all = entry.parameterGroups
        guard !query.isEmpty else { return all }
        return all.compactMap { group in
            let matches = group.parameters.filter {
                $0.label.localizedCaseInsensitiveContains(query) || $0.name.localizedCaseInsensitiveContains(query)
                    || (group.title?.localizedCaseInsensitiveContains(query) ?? false)
            }
            return matches.isEmpty ? nil : ShaderParameterGroup(title: group.title, parameters: matches)
        }
    }

    public var body: some View {
        #if os(tvOS)
        televisionEditor
            .navigationTitle(entry.displayName)
        #else
        List {
            SwiftUI.Section {
                HStack {
                    Spacer()
                    ShaderThumbnailView(entry: entry, size: Self.previewSize, revision: store.revision)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            if entry.editableParameters.isEmpty {
                Text(String(localized: "This filter has no adjustable settings."))
                    .foregroundColor(.secondary)
            }
            ForEach(groups) { group in
                SwiftUI.Section(header: group.title.map { Text($0) }) {
                    ForEach(group.parameters) { parameter in
                        parameterRow(parameter)
                    }
                }
            }
            if !entry.editableParameters.isEmpty {
                SwiftUI.Section {
                    Button(role: .destructive) {
                        store.resetParameters(of: entry.id)
                        onChange?()
                    } label: {
                        Label(String(localized: "Reset All to Defaults"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .navigationTitle(entry.displayName)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .modifier(SearchIfNeeded(isEnabled: entry.editableParameters.count > Self.searchThreshold, query: $query))
        #endif
    }

    #if os(tvOS)
    /// The preview stays outside the scrolling controls, including for presets with hundreds of parameters.
    private var televisionEditor: some View {
        GeometryReader { geometry in
            let previewWidth = min(geometry.size.width * 0.38, geometry.size.height * 0.8, 480)
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "LIVE PREVIEW"))
                        .retroPauseSectionHeaderTypography()
                        .foregroundStyle(Color.retroCyan)
                    ShaderThumbnailView(entry: entry,
                                        size: CGSize(width: previewWidth, height: previewWidth * 0.75),
                                        revision: store.revision)
                        .accessibilityIdentifier("shaderParameterPreview")
                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(String(localized: "Changes apply immediately."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(width: previewWidth, alignment: .leading)
                .accessibilityElement(children: .combine)

                VStack(spacing: 16) {
                    if entry.editableParameters.count > Self.searchThreshold {
                        TextField(String(localized: "Search settings"), text: $query)
                            .padding(12)
                            .background(RetroPauseSearchFieldBackground())
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if entry.editableParameters.isEmpty {
                                Text(String(localized: "This filter has no adjustable settings."))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(groups) { group in
                                VStack(alignment: .leading, spacing: 20) {
                                    if let title = group.title {
                                        Text(title)
                                            .retroPauseSectionHeaderTypography()
                                            .foregroundStyle(Color.retroCyan)
                                    }
                                    ForEach(group.parameters) { parameter in
                                        parameterRow(parameter)
                                            .padding(16)
                                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: RetroPauseChrome.radiusMD))
                                    }
                                }
                            }
                            if !entry.editableParameters.isEmpty {
                                Button(role: .destructive) {
                                    store.resetParameters(of: entry.id)
                                    onChange?()
                                } label: {
                                    Label(String(localized: "Reset All to Defaults"), systemImage: "arrow.counterclockwise")
                                        .padding(12)
                                }
                                .retroFocusButtonStyle(focusScale: 1.02, primaryColor: .retroPink)
                            }
                        }
                        // Keep focused controls and their glow clear of the scroll view's clipping edge.
                        .padding(12)
                    }
                    .accessibilityIdentifier("shaderParameterControls")
                    .focusSection()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    #endif

    @ViewBuilder
    private func parameterRow(_ parameter: ShaderParameterDescriptor) -> some View {
        let binding = Binding<Float>(
            get: { store.value(of: parameter, in: entry.id) },
            set: { newValue in
                store.setValue(newValue, of: parameter, in: entry.id)
                onChange?()
            }
        )
        HStack(alignment: .center) {
            if parameter.isToggle {
                Toggle(parameter.label, isOn: Binding(get: { binding.wrappedValue != 0 },
                                                      set: { binding.wrappedValue = $0 ? 1 : 0 }))
                    #if os(tvOS)
                    .tint(.retroCyan)
                    #endif
            } else {
                ShaderParameterSlider(label: parameter.label,
                                      value: binding,
                                      range: parameter.minimum ... parameter.maximum,
                                      step: parameter.step > 0 ? parameter.step : nil,
                                      palette: palette)
            }
            if store.isOverridden(parameter, in: entry.id) {
                Button {
                    store.setValue(nil, of: parameter, in: entry.id)
                    onChange?()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                }
                #if os(tvOS)
                .retroFocusButtonStyle(focusScale: 1.1, primaryColor: .retroCyan)
                #else
                .buttonStyle(.plain)
                #endif
                .accessibilityLabel(String(localized: "Reset \(parameter.label)"))
            }
        }
    }
}

/// `.searchable` only for presets with many settings.
private struct SearchIfNeeded: ViewModifier {
    let isEnabled: Bool
    @Binding var query: String

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $query, prompt: Text(String(localized: "Search settings")))
        } else {
            content
        }
    }
}

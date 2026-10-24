import SwiftUI
import PVSettings
import PVShaders
import PVSystems
import Defaults
import PVThemes
import PVUIBase

/// SF Symbol shared by the filter rows and sections.
private let filterSymbol = "camera.filters"

struct FilterSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ShaderPreviewService.usesTestPatternKey) private var previewsUseTestPattern = false

    private static let sectionSpacing: CGFloat = 24

    var body: some View {
        page
            .navigationTitle("Display Filters")
            #if os(tvOS)
            .focusSection()
            .onExitCommand { dismiss() }
            #endif
            .settingsSubpageTracking()
            .shaderPreviews()
    }

    @ViewBuilder
    private var page: some View {
        #if os(tvOS)
        ZStack {
            RetroSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    sections
                }
                .tvOSSettingsHorizontalPadding()
                .padding(.vertical, 24)
            }
        }
        #else
        Form {
            sections
        }
        #endif
    }

    @ViewBuilder
    private var sections: some View {
        DefaultFilterSection()
        ScopedFilterSections()
        FilterSection(icon: "photo", title: String(localized: "Previews"),
                      footer: String(localized: "While a game is paused, previews use its picture.")) {
            testPatternToggle
        }
        #if !os(tvOS)
        DualScreenLCDSection()
        #endif
        libraryCredits
    }

    @ViewBuilder
    private var testPatternToggle: some View {
        #if os(tvOS)
        ThemedToggle(isOn: $previewsUseTestPattern) {
            SettingsRow(title: String(localized: "Preview on Test Pattern"),
                        icon: .sfSymbol("rectangle.dashed"),
                        showChevron: false)
        }
        #else
        Toggle(String(localized: "Preview on Test Pattern"), isOn: $previewsUseTestPattern)
        #endif
    }

    @ViewBuilder
    private var libraryCredits: some View {
        let credits = String(localized: "Library filters are the libretro slang shader collection, converted to Metal. Provenance filters by Mr. J & Mame4iOS.")
        #if os(tvOS)
        Text(credits)
            .font(.retroSettingsRowSubtitle)
            .foregroundColor(.secondary)
        #else
        SwiftUI.Section(footer: Text(credits)) {
            EmptyView()
        }
        #endif
    }
}

/// A retrowave section on tvOS; a stock `Form` section elsewhere.
private struct FilterSection<Content: View>: View {
    let icon: String
    let title: String
    var footer: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if os(tvOS)
        SettingsPageSection(icon: icon, title: title, footer: footer, content: content)
        #else
        SwiftUI.Section {
            content()
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
            }
        }
        #endif
    }
}

/// The global filter: off, one filter everywhere, or picked by screen type.
private struct DefaultFilterSection: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case off, automatic, always
        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: return String(localized: "Off")
            case .automatic: return String(localized: "Automatic")
            case .always: return String(localized: "Always")
            }
        }
    }

    private let store = ShaderLibraryStore.shared
    private let catalog = ShaderCatalog.shared

    private var selection: ShaderSelection { store.selection(for: .global) ?? .off }

    private var mode: Binding<Mode> {
        Binding(
            get: {
                switch selection {
                case .off, .skinFilter: return .off
                case .auto: return .automatic
                case .always: return .always
                }
            },
            set: { newMode in
                switch newMode {
                case .off:
                    store.setSelection(.off, for: .global)
                case .automatic:
                    store.setSelection(.auto(crt: .native(.simpleCRT), lcd: .native(.lcd)), for: .global)
                case .always:
                    store.setSelection(.always(store.recents.first ?? .native(.complexCRT)), for: .global)
                }
            }
        )
    }

    var body: some View {
        FilterSection(icon: filterSymbol, title: String(localized: "Default Filter")) {
            SettingsChoiceGroup(
                title: String(localized: "Mode"),
                caption: String(localized: "Automatic picks a filter by screen type: CRT systems and LCD handhelds. Systems and games can override this from the pause menu."),
                icon: filterSymbol,
                options: Mode.allCases,
                optionTitle: { $0.title },
                selection: mode
            )
            switch selection {
            case .always(let id):
                pickerLink(String(localized: "Filter"), current: id) { picked in
                    store.setSelection(picked.map(ShaderSelection.always) ?? .off, for: .global)
                }
                editLink(id)
            case .auto(let crt, let lcd):
                pickerLink(String(localized: "CRT Systems"), current: crt) {
                    store.setSelection(.auto(crt: $0, lcd: lcd), for: .global)
                }
                pickerLink(String(localized: "LCD Handhelds"), current: lcd) {
                    store.setSelection(.auto(crt: crt, lcd: $0), for: .global)
                }
                if let crt { editLink(crt) }
                if let lcd { editLink(lcd) }
            case .off, .skinFilter:
                EmptyView()
            }
        }
    }

    /// A row that opens the browser and reports the picked filter (`nil` for Off).
    private func pickerLink(_ title: String, current: ShaderID?, onPick: @escaping (ShaderID?) -> Void) -> some View {
        NavigationLink {
            ShaderPickerScreen(title: title, current: current, onPick: onPick)
        } label: {
            let currentName = current.flatMap(catalog.entry(for:))?.displayName ?? String(localized: "Off")
            #if os(tvOS)
            SettingsRow(title: title, value: currentName, icon: .sfSymbol(filterSymbol))
            #else
            HStack {
                Text(title)
                Spacer()
                Text(currentName)
                    .foregroundColor(.secondary)
            }
            #endif
        }
        #if os(tvOS)
        .retroFocusButtonStyle(showBorder: false)
        #endif
    }

    @ViewBuilder
    private func editLink(_ id: ShaderID) -> some View {
        if let entry = catalog.entry(for: id), !entry.editableParameters.isEmpty {
            NavigationLink {
                ShaderParameterEditorView(entry: entry)
            } label: {
                let adjustTitle = String(localized: "Adjust \(entry.displayName)")
                #if os(tvOS)
                SettingsRow(title: adjustTitle, icon: .sfSymbol("slider.horizontal.3"))
                #else
                Label(adjustTitle, systemImage: "slider.horizontal.3")
                #endif
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
        }
    }
}

/// The browser as a settings screen: picking pops back.
private struct ShaderPickerScreen: View {
    let title: String
    let current: ShaderID?
    let onPick: (ShaderID?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ShaderBrowserView(current: current.map(ShaderBrowserChoice.shader) ?? .off) { choice in
            if case .shader(let id) = choice {
                onPick(id)
                ShaderLibraryStore.shared.noteUsed(id)
            } else {
                onPick(nil)
            }
            dismiss()
        }
        .navigationTitle(title)
    }
}

/// Per-system and per-game choices made from the pause menu.
private struct ScopedFilterSections: View {
    private let store = ShaderLibraryStore.shared
    private let catalog = ShaderCatalog.shared

    var body: some View {
        let systems = store.systemSelections.sorted { $0.key < $1.key }
        if !systems.isEmpty {
            FilterSection(icon: "cpu", title: String(localized: "System Filters")) {
                ForEach(systems, id: \.key) { systemID, selection in
                    systemRow(systemID: systemID, selection: selection)
                        .contextMenu {
                            Button(String(localized: "Use Default Filter"), role: .destructive) {
                                store.setSelection(nil, for: .system(systemID))
                            }
                        }
                        #if !os(tvOS)
                        .swipeActions {
                            Button(String(localized: "Remove"), role: .destructive) {
                                store.setSelection(nil, for: .system(systemID))
                            }
                        }
                        #endif
                }
            }
        }
        let games = store.gameSelections.count
        if games > 0 {
            FilterSection(icon: "gamecontroller", title: String(localized: "Game Filters")) {
                clearGamesButton(count: games)
            }
        }
    }

    @ViewBuilder
    private func systemRow(systemID: String, selection: ShaderSelection) -> some View {
        let name = SystemIdentifier(rawValue: systemID)?.fullName ?? systemID
        #if os(tvOS)
        // Focusable so the context menu (long-press) can reach it; the row has no tap action.
        SettingsRow(title: name, value: describe(selection), showChevron: false)
            .focusable()
            .retroFocusEffect(focusScale: 1.04, cornerRadius: 12)
        #else
        HStack {
            Text(name)
            Spacer()
            Text(describe(selection)).foregroundColor(.secondary)
        }
        #endif
    }

    @ViewBuilder
    private func clearGamesButton(count: Int) -> some View {
        let title = String(localized: "Clear \(count) Per-Game Filters")
        #if os(tvOS)
        RetroSettingsActionButton(title: title, icon: "trash", color: .red) {
            store.clearGameSelections()
        }
        #else
        Button(title, role: .destructive) {
            store.clearGameSelections()
        }
        #endif
    }

    private func describe(_ selection: ShaderSelection) -> String {
        switch selection {
        case .off: return String(localized: "Off")
        case .skinFilter: return String(localized: "Skin's Filter")
        case .auto: return String(localized: "Automatic")
        case .always(let id): return catalog.entry(for: id)?.displayName ?? id.path
        }
    }
}

#if !os(tvOS)
/// DS and 3DS skins draw each screen on its own, so the filters above never reach them.
private struct DualScreenLCDSection: View {
    @Default(.dualScreenLCDLook) private var dualScreenLCDLook

    var body: some View {
        FilterSection(icon: "rectangle.split.2x1", title: String(localized: "Dual-Screen Handhelds"),
                      footer: String(localized: """
                          DS and 3DS skins don't use the filters above. This gives their screens an LCD pixel grid, \
                          a little softness and muted colour; 3DS gets the grid only. A skin's own screen filter \
                          takes priority.
                          """)) {
            Toggle(String(localized: "LCD look on dual-screen handhelds"), isOn: $dualScreenLCDLook)
        }
    }
}
#endif

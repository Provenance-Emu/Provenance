import SwiftUI
import PVSettings
import PVShaders
import PVSystems
import Defaults
import PVThemes
import PVUIBase

struct FilterSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Default(.openGLFilterMode) var openGLFilterMode

    var body: some View {
        Form {
            DefaultFilterSection()
            ScopedFilterSections()
            OpenGLFilterSection(openGLFilterMode: $openGLFilterMode)
            SwiftUI.Section(footer: Text(String(localized: "Library filters are the libretro slang shader collection, converted to Metal. Provenance filters by Mr. J & Mame4iOS."))) {
                EmptyView()
            }
        }
        #if os(tvOS)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.retroPurple.opacity(0.1),
                    Color.retroPink.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        #endif
        .navigationTitle("Display Filters")
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
        .shaderPreviews()
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
        SwiftUI.Section(header: Text(String(localized: "Default Filter")),
                        footer: Text(String(localized: "Automatic picks a filter by screen type: CRT systems and LCD handhelds. Systems and games can override this from the pause menu."))) {
            Picker(String(localized: "Mode"), selection: mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
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
            HStack {
                Text(title)
                Spacer()
                Text(current.flatMap(catalog.entry(for:))?.name.capitalized ?? String(localized: "Off"))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func editLink(_ id: ShaderID) -> some View {
        if let entry = catalog.entry(for: id), !entry.editableParameters.isEmpty {
            NavigationLink {
                ShaderParameterEditorView(entry: entry)
            } label: {
                Label(String(localized: "Adjust \(entry.name.capitalized)"), systemImage: "slider.horizontal.3")
            }
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
            SwiftUI.Section(header: Text(String(localized: "System Filters"))) {
                ForEach(systems, id: \.key) { systemID, selection in
                    HStack {
                        Text(SystemIdentifier(rawValue: systemID)?.fullName ?? systemID)
                        Spacer()
                        Text(describe(selection)).foregroundColor(.secondary)
                    }
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
            SwiftUI.Section(header: Text(String(localized: "Game Filters"))) {
                Button(String(localized: "Clear \(games) Per-Game Filters"), role: .destructive) {
                    store.clearGameSelections()
                }
            }
        }
    }

    private func describe(_ selection: ShaderSelection) -> String {
        switch selection {
        case .off: return String(localized: "Off")
        case .skinFilter: return String(localized: "Skin's Filter")
        case .auto: return String(localized: "Automatic")
        case .always(let id): return catalog.entry(for: id)?.name.capitalized ?? id.path
        }
    }
}

private struct OpenGLFilterSection: View {
    @Binding var openGLFilterMode: OpenGLFilterModeOption

    var body: some View {
        Section(header:
            Text("OpenGL Filters")
                #if os(tvOS)
                .foregroundColor(.retroPink)
                .font(.headline)
                #endif
        ) {
            Picker("Filter Type", selection: $openGLFilterMode) {
                ForEach(OpenGLFilterModeOption.allCases, id: \.self) { filter in
                    Text(filter.description).tag(filter)
                }
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            .tint(.retroBlue)
            #endif
        }
    }
}

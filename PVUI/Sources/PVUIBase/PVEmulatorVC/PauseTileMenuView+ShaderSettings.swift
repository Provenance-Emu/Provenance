//
//  PauseTileMenuView+ShaderSettings.swift
//  PVUI
//
//  Filter browser and parameter editor for the pause menu. Choices
//  apply immediately and the paused frame redraws, so the game behind the
//  sheet previews them live.
//

import SwiftUI
import PVShaders
import PVThemes

/// Which scope a pause-menu choice is saved to.
enum ShaderPauseScope: String, CaseIterable, Identifiable {
    case game, system, everywhere

    var id: String { rawValue }

    var title: String {
        switch self {
        case .game: return String(localized: "This Game")
        case .system: return String(localized: "This System")
        case .everywhere: return String(localized: "Everywhere")
        }
    }
}

/// Sheet shown from the pause menu (Screen Filter and Shader Settings).
struct ShaderPauseSheet: View {
    let emulatorVC: PVEmulatorViewController
    /// Open on the active filter's parameters instead of the browser.
    var startInEditor = false

    @Environment(\.dismiss) private var dismiss
    @State private var scope: ShaderPauseScope = .game
    #if os(tvOS)
    @State private var editingEntry: ShaderCatalogEntry?
    #endif
    private let store = ShaderLibraryStore.shared

    private var shaderScope: ShaderScope {
        switch scope {
        case .game: return emulatorVC.shaderGameMD5.map(ShaderScope.game) ?? .global
        case .system: return emulatorVC.shaderSystemID.map(ShaderScope.system) ?? .global
        case .everywhere: return .global
        }
    }

    /// The active filter's catalog entry, if it has settings to edit.
    private var activeEntry: ShaderCatalogEntry? {
        emulatorVC.activeShaderSelection.shader(for: emulatorVC.core.screenType).flatMap(ShaderCatalog.shared.entry(for:))
    }

    var body: some View {
        #if os(tvOS)
        televisionPanel
            .shaderPreviews()
            .onExitCommand(perform: goBack)
            .onAppear {
                scope = initialScope
                if startInEditor { editingEntry = activeEntry }
            }
        #else
        NavigationStack {
            Group {
                if startInEditor, let entry = activeEntry {
                    ShaderParameterEditorView(entry: entry) { emulatorVC.shaderParametersDidChange() }
                } else {
                    browser
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
        .shaderPreviews()
        #if os(iOS)
        // Leave the game visible above the sheet so choices preview on it.
        .presentationDetents([.medium, .large])
        #endif
        .onAppear { scope = initialScope }
        #endif
    }

    #if os(tvOS)
    /// Use the same panel and focus chrome as the pause menu, without the narrow system sheet.
    private var televisionPanel: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 24) {
                    HStack(spacing: 24) {
                        if editingEntry != nil, !startInEditor {
                            Button(action: goBack) {
                                Label(String(localized: "Back"), systemImage: "chevron.left")
                                    .padding(12)
                            }
                            .retroFocusButtonStyle(focusScale: 1.04, primaryColor: .retroCyan)
                        }
                        Text(editingEntry?.displayName ?? String(localized: "Screen Filters"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Button { dismiss() } label: {
                            Label(String(localized: "Done"), systemImage: "checkmark")
                                .padding(12)
                        }
                        .retroFocusButtonStyle(focusScale: 1.04, primaryColor: .retroCyan)
                    }
                    .focusSection()
                    if let entry = editingEntry {
                        ShaderParameterEditorView(entry: entry) { emulatorVC.shaderParametersDidChange() }
                    } else {
                        browser
                    }
                }
                .padding(32)
                .frame(width: min(1400, max(0, geometry.size.width - 120)), height: geometry.size.height * 0.86)
                .background(RetroPausePanelBackground(isDark: true))
                .shadow(color: .retroPurple.opacity(0.25), radius: 18)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(.clear)
    }

    private func goBack() {
        if editingEntry != nil, !startInEditor {
            editingEntry = nil
        } else {
            dismiss()
        }
    }

    private var scopeControls: some View {
        HStack(spacing: 20) {
            Text(String(localized: "Apply to"))
                .foregroundStyle(.white.opacity(0.65))
            ForEach(ShaderPauseScope.allCases) { option in
                Button { scope = option } label: {
                    HStack(spacing: 8) {
                        Text(option.title)
                        if scope == option { Image(systemName: "checkmark") }
                    }
                    .padding(12)
                }
                .retroFocusButtonStyle(focusScale: 1.04, primaryColor: .retroCyan)
                .accessibilityAddTraits(scope == option ? .isSelected : [])
            }
            Spacer()
        }
        .focusSection()
    }
    #endif

    private var browser: some View {
        VStack(spacing: 0) {
            #if os(tvOS)
            scopeControls.padding(.bottom, 20)
            #else
            Picker(String(localized: "Apply to"), selection: $scope) {
                ForEach(ShaderPauseScope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            #endif

            if scope != .everywhere, store.selection(for: shaderScope) != nil {
                Button(String(localized: "Use the \(scope == .game ? String(localized: "system") : String(localized: "global")) filter instead")) {
                    store.setSelection(nil, for: shaderScope)
                    emulatorVC.shaderSelectionDidChange()
                }
                .font(.footnote)
                .padding(.bottom, 4)
                #if os(tvOS)
                .retroFocusButtonStyle(focusScale: 1.02, primaryColor: .retroCyan)
                #endif
            }

            ShaderBrowserView(current: currentChoice,
                              showsSkinFilter: emulatorVC.currentSkinProvidesScreenFilter,
                              onParametersChange: { emulatorVC.shaderParametersDidChange() },
                              onEdit: editFromBrowser) { choice in
                store.setSelection(choice.selection, for: shaderScope)
                emulatorVC.shaderSelectionDidChange()
            }
        }
        .navigationTitle(String(localized: "Screen Filter"))
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var editFromBrowser: ((ShaderCatalogEntry) -> Void)? {
        #if os(tvOS)
        return { editingEntry = $0 }
        #else
        return nil
        #endif
    }

    /// The scope's own choice, or the inherited one shown as current.
    private var currentChoice: ShaderBrowserChoice {
        ShaderBrowserChoice(store.selection(for: shaderScope) ?? emulatorVC.activeShaderSelection)
    }

    /// Start on the scope whose selection is in effect, so edits change what is on screen.
    private var initialScope: ShaderPauseScope {
        switch store.effectiveScope(gameMD5: emulatorVC.shaderGameMD5, systemID: emulatorVC.shaderSystemID) {
        case .game: return .game
        case .system: return .system
        case .global: return .everywhere
        }
    }
}

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
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
        .onAppear { scope = initialScope }
    }

    private var browser: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Apply to"), selection: $scope) {
                ForEach(ShaderPauseScope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if scope != .everywhere, store.selection(for: shaderScope) != nil {
                Button(String(localized: "Use the \(scope == .game ? String(localized: "system") : String(localized: "global")) filter instead")) {
                    store.setSelection(nil, for: shaderScope)
                    emulatorVC.shaderSelectionDidChange()
                }
                .font(.footnote)
                .padding(.bottom, 4)
            }

            ShaderBrowserView(current: currentChoice,
                              showsSkinFilter: emulatorVC.currentSkinProvidesScreenFilter) { choice in
                store.setSelection(choice.selection, for: shaderScope)
                emulatorVC.shaderSelectionDidChange()
            }
        }
        .navigationTitle(String(localized: "Screen Filter"))
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
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

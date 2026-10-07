//
//  PauseTileMenuView+ControllerLayout.swift
//  PVUI
//
//  "Controller Layout" sheet for the pause menu: picks the controller variant
//  (Genesis 3-/6-button, Wii remote upright / sideways, …) for this game or for every game of the
//  system, and applies it to a core that can switch live. The programmatic overlay
//  redraws from the same settings (`OverlayPadKindResolver`). iOS only, like the overlay.
//

#if !os(tvOS)
import SwiftUI
import Defaults
import PVCoreBridge
import PVEmulatorCore
import PVSettings
import PVSystems
import PVThemes

/// What the sheet edits, captured on the main thread when the menu entry is tapped.
struct ControllerLayoutSheetContext: Identifiable {
    let system: SystemIdentifier
    let variants: [ControllerLayoutVariant]
    /// Empty when the game has no hash: only the per-system scope is offered then.
    let gameMD5: String
    var id: String { system.rawValue }
}

extension PauseTileMenuView {
    /// The game's system (resolved like the overlay resolves it), the variants the overlay can
    /// draw for it and the game's hash, or `nil` when there is no choice to offer.
    func makeControllerLayoutContext() -> ControllerLayoutSheetContext? {
        guard let game = emulatorVC.game, !game.isInvalidated,
              let system = ProgrammaticOverlaySupport.systemIdentifier(linked: game.system?.systemIdentifier,
                                                                       persisted: game.systemIdentifier),
              OverlayPadKindResolver.offersVariantChoice(for: system) else { return nil }
        return ControllerLayoutSheetContext(system: system,
                                            variants: OverlayPadKindResolver.selectableVariants(for: system),
                                            gameMD5: game.md5Hash)
    }
}

struct ControllerLayoutPauseSheet: View {
    enum Scope: Hashable { case game, system }

    let context: ControllerLayoutSheetContext
    let core: PVEmulatorCore
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Default(.controllerLayoutVariantsByGame) private var variantsByGame
    @Default(.controllerLayoutVariantsBySystem) private var variantsBySystem
    @State private var scope: Scope

    init(context: ControllerLayoutSheetContext, core: PVEmulatorCore) {
        self.context = context
        self.core = core
        let hasGameChoice = !context.gameMD5.isEmpty
            && Defaults[.controllerLayoutVariantsByGame][context.gameMD5] != nil
        _scope = State(initialValue: hasGameChoice ? .game : .system)
    }

    private var palette: UXThemePalette { themeManager.currentPalette }

    /// The variant this scope resolves to today: its stored choice, else what the overlay draws.
    private var selectedID: String {
        let stored = scope == .game ? variantsByGame[context.gameMD5] : variantsBySystem[context.system.rawValue]
        return stored ?? OverlayPadKindResolver.padKind(for: context.system,
                                                        variantProvider: core as? ConsoleVariantConfigurable,
                                                        gameMD5: context.gameMD5).subtype
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !context.gameMD5.isEmpty {
                        Picker(String(localized: "Applies to"), selection: $scope) {
                            Text(String(localized: "This game")).tag(Scope.game)
                            Text(String(localized: "All \(context.system.systemName) games")).tag(Scope.system)
                        }
                        .pickerStyle(.segmented)
                    }
                    ForEach(context.variants) { variant in
                        variantRow(variant, isSelected: variant.id == selectedID)
                    }
                }
                .padding()
            }
            .background(Color(palette.gameLibraryBackground).ignoresSafeArea())
            .navigationTitle(String(localized: "Controller Layout"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }

    private func variantRow(_ variant: ControllerLayoutVariant, isSelected: Bool) -> some View {
        Button {
            select(variant.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: variant.sfSymbol)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.displayName)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                    if let detail = variant.description {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding(10)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(isSelected ? 0.12 : 0.04)))
        }
        .buttonStyle(.plain)
    }

    /// Stores the choice, then switches a core that can apply it while running. "All games"
    /// also drops this game's own choice, which would otherwise keep winning.
    private func select(_ variantID: String) {
        switch scope {
        case .game:
            Defaults[.controllerLayoutVariantsByGame][context.gameMD5] = variantID
        case .system:
            Defaults.setControllerLayoutVariant(variantID, forSystemID: context.system.rawValue)
            if !context.gameMD5.isEmpty {
                Defaults[.controllerLayoutVariantsByGame].removeValue(forKey: context.gameMD5)
            }
        }
        (core as? ConsoleVariantConfigurable)?.applyControllerLayoutVariant(variantID)
    }
}
#endif

//
//  MouseGameSettingsView.swift
//  PVUIBase
//
//  Per-game mouse input override shown in the Game Info screen.
//  Only renders for games whose system has any mouse support.
//

import SwiftUI
import PVCoreBridge

/// Compact SwiftUI row that lets users configure the per-game mouse input override.
///
/// Appears in `GameMoreInfoView` when the game belongs to a mouse-capable system.
/// The choice is persisted via `MouseGameRegistry.shared.setUserOverride(_:forMD5:)`,
/// keyed by the game's MD5 hash.
///
/// Three options are presented:
/// - **Auto** — let `MouseGameRegistry` auto-detect (default)
/// - **Always On** — force mouse input enabled for this game
/// - **Always Off** — force mouse input disabled for this game
struct MouseGameSettingsView: View {

    /// MD5 hash of the game — used as the persistence key.
    let gameMD5: String

    let accentColor: Color
    let backgroundColor: Color
    let borderGradient: LinearGradient

    /// Three-state selection mirroring `MouseGameRegistry.userOverride(forMD5:)`.
    /// - `nil`   → Auto (no override stored)
    /// - `true`  → Always On
    /// - `false` → Always Off
    @State private var currentOverride: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Image(systemName: "computermouse.fill")
                    .foregroundColor(accentColor)
                Text("MOUSE INPUT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor)
                Spacer()
            }

            // Picker
            #if os(tvOS)
            tvOSPicker
            #else
            iOSSegmentedPicker
            #endif

            // Description
            Text("Override automatic mouse detection for this game")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding(12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderGradient, lineWidth: 1)
        )
        .onAppear {
            currentOverride = MouseGameRegistry.shared.userOverride(forMD5: gameMD5)
        }
    }

    // MARK: - Picker Options

    private enum MouseOverrideOption: String, CaseIterable, Identifiable {
        case auto       = "auto"
        case alwaysOn   = "always_on"
        case alwaysOff  = "always_off"

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .auto:      return "Auto"
            case .alwaysOn:  return "Always On"
            case .alwaysOff: return "Always Off"
            }
        }

        var sfSymbolName: String {
            switch self {
            case .auto:      return "gearshape"
            case .alwaysOn:  return "computermouse.fill"
            case .alwaysOff: return "computermouse"
            }
        }

        /// Convert from the three-state `Bool?` stored in `MouseGameRegistry`.
        init(override: Bool?) {
            switch override {
            case .none:  self = .auto
            case .some(true):  self = .alwaysOn
            case .some(false): self = .alwaysOff
            }
        }

        /// Convert to the `Bool?` expected by `MouseGameRegistry.setUserOverride(_:forMD5:)`.
        var overrideValue: Bool? {
            switch self {
            case .auto:      return nil
            case .alwaysOn:  return true
            case .alwaysOff: return false
            }
        }
    }

    // MARK: - Platform Pickers

    private var iOSSegmentedPicker: some View {
        Picker("Mouse Input", selection: Binding(
            get: { MouseOverrideOption(override: currentOverride) },
            set: { save($0) }
        )) {
            ForEach(MouseOverrideOption.allCases) { option in
                Label(option.displayTitle, systemImage: option.sfSymbolName)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var tvOSPicker: some View {
        Picker("Mouse Input", selection: Binding(
            get: { MouseOverrideOption(override: currentOverride) },
            set: { save($0) }
        )) {
            ForEach(MouseOverrideOption.allCases) { option in
                HStack {
                    Image(systemName: option.sfSymbolName)
                    Text(option.displayTitle)
                }
                .tag(option)
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Persistence

    private func save(_ option: MouseOverrideOption) {
        currentOverride = option.overrideValue
        MouseGameRegistry.shared.setUserOverride(option.overrideValue, forMD5: gameMD5)
    }
}

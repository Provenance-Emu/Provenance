//
//  JITGameSettingsView.swift
//  PVUIBase
//
//  Per-game JIT preference toggle shown in the Game Info screen.
//  Only renders for games whose system has JIT-capable emulator cores.
//

import SwiftUI
import PVSettings
import Defaults

/// Compact SwiftUI row that lets users configure the per-game JIT preference.
///
/// Appears in `GameMoreInfoView` when the game belongs to a JIT-capable system.
/// The choice is persisted via `Defaults[.jitGamePreferences]` keyed by the
/// game's MD5 hash, so it survives app restarts without touching Realm.
struct JITGameSettingsView: View {

    /// MD5 hash of the game — used as the persistence key.
    let gameMD5: String

    let accentColor: Color
    let backgroundColor: Color
    let borderGradient: LinearGradient

    @Default(.jitGamePreferences) private var preferences

    private var currentPreference: JITGamePreference {
        preferences[gameMD5] ?? .automatic
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .foregroundColor(accentColor)
                Text("JIT / PERFORMANCE MODE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor)
                Spacer()
            }

            // Picker
            #if os(tvOS)
            tvOSPreferencePicker
            #else
            iOSSegmentedPicker
            #endif

            // Description line
            Text(currentPreference.displayDescription)
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
    }

    // MARK: - Platform Pickers

    private var iOSSegmentedPicker: some View {
        Picker("JIT Mode", selection: Binding(
            get: { currentPreference },
            set: { save($0) }
        )) {
            ForEach(JITGamePreference.allCases, id: \.self) { pref in
                Label(pref.displayTitle, systemImage: pref.sfSymbolName)
                    .tag(pref)
            }
        }
        .pickerStyle(.segmented)
    }

    private var tvOSPreferencePicker: some View {
        Picker("JIT Mode", selection: Binding(
            get: { currentPreference },
            set: { save($0) }
        )) {
            ForEach(JITGamePreference.allCases, id: \.self) { pref in
                HStack {
                    Image(systemName: pref.sfSymbolName)
                    Text(pref.displayTitle)
                }
                .tag(pref)
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Persistence

    private func save(_ preference: JITGamePreference) {
        if preference == .automatic {
            preferences.removeValue(forKey: gameMD5)
        } else {
            preferences[gameMD5] = preference
        }
    }
}

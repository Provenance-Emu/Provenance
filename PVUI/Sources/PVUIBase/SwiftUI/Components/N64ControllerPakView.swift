//
//  N64ControllerPakView.swift
//  PVUIBase
//
//  Part of #2745 — Haptics Tier 4: N64 controller slot UI
//
//  Provides a dedicated, user-friendly UI for choosing the accessory type
//  (pak) inserted into each of the four N64 controller ports.
//
//  The N64 supports four distinct pak types per controller slot:
//  • Memory Pak  — saves game data (e.g. GoldenEye, Donkey Kong 64)
//  • Rumble Pak  — vibration-only accessory (no saves)
//  • Transfer Pak — mounts a GB/GBC cartridge (Pokémon Stadium, etc.)
//  • Smart Pak   — virtual combo that provides both saves AND rumble
//
//  Selections are stored via the same UserDefaults keys used by
//  MupenGameCoreOptions (`MupenGameCoreOptions.Controller Pak N`), so
//  changes here take effect the next time a ROM is loaded (requiresRestart).
//
//  This view can optionally be scoped to a specific game's MD5 hash so
//  per-game overrides are stored separately from the global defaults.
//

import SwiftUI
import PVLogging

// MARK: - N64 Pak Type

/// Mirrors the PLUGIN_* constants from the Mupen64Plus input API and the
/// values defined in MupenGameCoreOptions.controllerPakOption(forController:).
public enum N64PakType: Int, CaseIterable, Identifiable {
    case auto       = 0
    case none       = 1
    case memoryPak  = 2
    case rumblePak  = 3
    case transferPak = 4
    case smartPak   = 5

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .auto:        return "Auto (ROM Database)"
        case .none:        return "None"
        case .memoryPak:   return "Memory Pak"
        case .rumblePak:   return "Rumble Pak"
        case .transferPak: return "Transfer Pak"
        case .smartPak:    return "Smart Pak (Memory + Rumble)"
        }
    }

    public var subtitle: String {
        switch self {
        case .auto:
            return "Let the ROM database choose the best pak type."
        case .none:
            return "No accessory — some games may not save."
        case .memoryPak:
            return "Persistent save storage. No rumble."
        case .rumblePak:
            return "Vibration feedback only. No memory saves."
        case .transferPak:
            return "Mount a GB/GBC cartridge in this slot."
        case .smartPak:
            return "Virtual combo: saves AND rumble in one slot."
        }
    }

    public var systemImage: String {
        switch self {
        case .auto:        return "wand.and.stars"
        case .none:        return "minus.circle"
        case .memoryPak:   return "memorychip"
        case .rumblePak:   return "waveform.path"
        case .transferPak: return "arrow.triangle.2.circlepath"
        case .smartPak:    return "star.fill"
        }
    }
}

// MARK: - N64 Pak Store

/// Thin wrapper for reading and writing N64 pak type selections via the same
/// UserDefaults keys used by MupenGameCoreOptions, making this view compatible
/// with existing core-option persistence without importing the Mupen module.
public enum N64PakStore {
    /// The UserDefaults class-name prefix used by MupenGameCoreOptions.
    private static let className = "MupenGameCoreOptions"

    /// Returns the stored pak type for the given 1-based port index.
    /// Falls back to `.auto` if nothing is stored.
    public static func pakType(forPort port: Int, gameMD5: String? = nil) -> N64PakType {
        let optionKey = "Controller Pak \(port)"
        let value: Int?
        if let md5 = gameMD5, !md5.isEmpty {
            let md5Key = "\(className).\(md5).\(optionKey)"
            value = UserDefaults.standard.object(forKey: md5Key) as? Int
                ?? UserDefaults.standard.object(forKey: "\(className).\(optionKey)") as? Int
        } else {
            value = UserDefaults.standard.object(forKey: "\(className).\(optionKey)") as? Int
        }
        return N64PakType(rawValue: value ?? 0) ?? .auto
    }

    /// Stores the pak type for the given 1-based port.
    /// When `gameMD5` is provided, the setting is scoped to that game;
    /// otherwise it updates the global per-core default.
    public static func setPakType(_ type: N64PakType, forPort port: Int, gameMD5: String? = nil) {
        let optionKey = "Controller Pak \(port)"
        let key: String
        if let md5 = gameMD5, !md5.isEmpty {
            key = "\(className).\(md5).\(optionKey)"
        } else {
            key = "\(className).\(optionKey)"
        }
        UserDefaults.standard.set(type.rawValue, forKey: key)
        DLOG("N64PakStore: set port \(port) → \(type.title) (key: \(key))")
    }
}

// MARK: - N64ControllerPakView

/// User-friendly sheet for configuring the N64 controller pak type per port.
///
/// Present this from the game context menu (before launch) or from the pause
/// menu during emulation. Changes take effect on next ROM load.
public struct N64ControllerPakView: View {

    /// Optional game MD5 for per-game overrides. When `nil`, changes update
    /// the global per-core default (applies to all N64 games).
    let gameMD5: String?
    let gameTitle: String?
    var onDismiss: (() -> Void)?

    @State private var selectedTypes: [N64PakType] = Array(repeating: .auto, count: 4)

    public init(gameMD5: String? = nil,
                gameTitle: String? = nil,
                onDismiss: (() -> Void)? = nil) {
        self.gameMD5 = gameMD5
        self.gameTitle = gameTitle
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            List {
                infoSection
                portsSection
            }
            #if os(tvOS)
            .listStyle(.plain)
            #else
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("Controller Paks")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss?() }
                }
            }
            .onAppear { loadSelections() }
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("N64 Controller Paks", systemImage: "gamecontroller.fill")
                    .font(.headline)
                Text("""
Each N64 controller port supports a different accessory. \
Choose the pak type for each port below. \
Changes take effect the next time the game is loaded.
""")
                .font(.footnote)
                .foregroundStyle(.secondary)
                if let title = gameTitle {
                    Text("Game: \(title)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var portsSection: some View {
        Section(header: Text("Controller Ports")) {
            ForEach(0..<4, id: \.self) { index in
                portRow(index: index)
            }
        }
    }

    // MARK: - Port Row

    @ViewBuilder
    private func portRow(index: Int) -> some View {
        let port = index + 1
        let selected = selectedTypes[index]

        Picker(selection: Binding(
            get: { selectedTypes[index] },
            set: { newValue in
                selectedTypes[index] = newValue
                N64PakStore.setPakType(newValue, forPort: port, gameMD5: gameMD5)
            }
        )) {
            ForEach(N64PakType.allCases) { pakType in
                HStack {
                    Image(systemName: pakType.systemImage)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pakType.title)
                        Text(pakType.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(pakType)
            }
        } label: {
            HStack {
                Image(systemName: "gamecontroller")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Controller \(port)")
                        .font(.body.weight(.medium))
                    Text(selected.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        #if !os(tvOS)
        .pickerStyle(.navigationLink)
        #endif
    }

    // MARK: - Data

    private func loadSelections() {
        for index in 0..<4 {
            selectedTypes[index] = N64PakStore.pakType(forPort: index + 1, gameMD5: gameMD5)
        }
    }
}

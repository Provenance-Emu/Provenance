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

    /// Retrowave accent color for this pak type.
    public var accentColor: Color {
        switch self {
        case .auto:        return Color.retroBlue
        case .none:        return Color.white.opacity(0.3)
        case .memoryPak:   return Color.retroCyan
        case .rumblePak:   return Color.retroOrange
        case .transferPak: return Color.retroPink
        case .smartPak:    return Color.retroYellow
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

    /// Shown in the info card; markdown used for inline emphasis when parsing succeeds.
    private static let infoCardMarkdown = "Choose the pak type for each controller port. Most games need a **Memory Pak** to save. Pokémon Stadium needs a **Transfer Pak**."

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
            ScrollView {
                VStack(spacing: 16) {
                    infoCard
                    portsCard
                    restartNote
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background {
                ZStack {
                    Color.retroBlack
                    RetroGrid(lineSpacing: 28, lineColor: Color.retroPurple.opacity(0.22))
                }
                .ignoresSafeArea()
            }
            .navigationTitle("")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    RetroGlowText("CONTROLLER PAKS", fontSize: 15)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss?() }
                        .foregroundStyle(Color.retroPink)
                }
            }
            .toolbarBackground(Color.retroBlack.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { loadSelections() }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.title2)
                .foregroundStyle(Color.retroPink)
                .shadow(color: Color.retroPink.opacity(0.7), radius: 6)

            VStack(alignment: .leading, spacing: 6) {
                if let title = gameTitle {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.retroYellow)
                }
                infoCardInstructionText
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroDarkBlue.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.retroPink.opacity(0.35), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.retroPink.opacity(0.15), radius: 8)
    }

    /// Renders bold segments from markdown when parsing succeeds; otherwise shows plain copy without asterisks.
    @ViewBuilder
    private var infoCardInstructionText: some View {
        let plainFallback = Self.infoCardMarkdown.replacingOccurrences(of: "**", with: "")
        if let attributed = try? AttributedString(
            markdown: Self.infoCardMarkdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        } else {
            Text(plainFallback)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Ports Card

    private var portsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color.retroBlue)
                Text("CONTROLLER PORTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.retroBlue)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .background(Color.retroPurple.opacity(0.4))

            ForEach(0..<4, id: \.self) { index in
                portRow(index: index)
                if index < 3 {
                    Divider()
                        .background(Color.retroPurple.opacity(0.2))
                        .padding(.horizontal, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroDarkBlue.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.retroBlue.opacity(0.5), Color.retroPurple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color.retroBlue.opacity(0.2), radius: 10)
    }

    // MARK: - Port Row

    /// Circular icon for the selected pak type on this port.
    @ViewBuilder
    private func portBadge(selected: N64PakType) -> some View {
        ZStack {
            Circle()
                .fill(selected.accentColor.opacity(0.18))
                .overlay(Circle().strokeBorder(selected.accentColor.opacity(0.5), lineWidth: 1.5))
                .frame(width: 36, height: 36)
            Image(systemName: selected.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected.accentColor)
        }
        .accessibilityHidden(true)
    }

    /// Middle column fills space between badge and trailing menu; `minWidth: 0` lets subtitles wrap on narrow widths.
    @ViewBuilder
    private func portLabels(port: Int, selected: N64PakType) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Controller \(port)")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
            Text(selected.subtitle)
                .font(.caption2)
                .foregroundStyle(selected.accentColor.opacity(0.8))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    /// Trailing menu control only (no `maxWidth: .infinity`); matches `TransferPakConfigView` so portrait sheets keep normal horizontal margins.
    @ViewBuilder
    private func pakTypeMenuChip(selected: N64PakType) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text(selected.title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .foregroundStyle(selected.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected.accentColor.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected.accentColor.opacity(0.4), lineWidth: 1))
        )
    }

    @ViewBuilder
    private func pakTypeMenu(port: Int, index: Int, selected: N64PakType) -> some View {
        Menu {
            ForEach(N64PakType.allCases) { pakType in
                Button {
                    selectedTypes[index] = pakType
                    N64PakStore.setPakType(pakType, forPort: port, gameMD5: gameMD5)
                } label: {
                    HStack {
                        Image(systemName: pakType.systemImage)
                        VStack(alignment: .leading) {
                            Text(pakType.title)
                            Text(pakType.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if selectedTypes[index] == pakType {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            pakTypeMenuChip(selected: selected)
        }
        .accessibilityLabel("Select pak type for Controller \(port)")
    }

    @ViewBuilder
    private func portRow(index: Int) -> some View {
        let port = index + 1
        let selected = selectedTypes[index]

        HStack(alignment: .top, spacing: 12) {
            portBadge(selected: selected)
            portLabels(port: port, selected: selected)
            pakTypeMenu(port: port, index: index, selected: selected)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Restart Note

    private var restartNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.clockwise.circle")
                .foregroundStyle(Color.retroYellow)
                .font(.caption)
            Text("Changes take effect the next time the game loads.")
                .font(.caption)
                .foregroundStyle(Color.retroYellow.opacity(0.75))
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.retroYellow.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.retroYellow.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Data

    private func loadSelections() {
        for index in 0..<4 {
            selectedTypes[index] = N64PakStore.pakType(forPort: index + 1, gameMD5: gameMD5)
        }
    }
}

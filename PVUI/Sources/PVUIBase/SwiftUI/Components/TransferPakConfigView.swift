//
//  TransferPakConfigView.swift
//  PVUI
//
//  Part of #3027 — Transfer Pak UI for Mupen64Plus N64 cores
//
//  The Transfer Pak is an N64 controller accessory that lets you slot in a
//  Game Boy or Game Boy Color cartridge. N64 games such as Pokémon Stadium,
//  Pokémon Stadium 2, and Mario Tennis can then read and write that cartridge's
//  save data (and ROM) directly, enabling cross-game features like unlocking
//  Pokémon from your GBC save or playing GB games on your TV.
//
//  This view lets the user pick which GB/GBC ROM to mount in each of the four
//  virtual controller-port Transfer Pak slots before (or during) emulation.
//  Selections are persisted in UserDefaults keyed by the N64 game's MD5 hash.
//

import SwiftUI
import PVLibrary
import PVCoreBridge
import PVLogging
import RealmSwift

// MARK: - Transfer Pak persistent store

/// UserDefaults-backed storage for per-game Transfer Pak ROM selections.
/// Keys follow the pattern: `PVTransferPak.<md5>.port<0..3>` → absolute path string.
public enum TransferPakStore {
    private static let keyPrefix = "PVTransferPak"

    public static func romPath(forGameMD5 md5: String, port: Int) -> URL? {
        let key = udKey(md5: md5, port: port)
        guard let path = UserDefaults.standard.string(forKey: key) else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public static func setRomPath(_ url: URL?, forGameMD5 md5: String, port: Int) {
        let key = udKey(md5: md5, port: port)
        if let url = url {
            UserDefaults.standard.set(url.path, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Returns `TransferPakROM` structs for all configured ports (0-based, up to `slotCount`).
    public static func allROMs(forGameMD5 md5: String, slotCount: Int = 4) -> [Int: TransferPakROM] {
        var result: [Int: TransferPakROM] = [:]
        for port in 0..<slotCount {
            if let path = romPath(forGameMD5: md5, port: port) {
                result[port] = TransferPakROM(romPath: path)
            }
        }
        return result
    }

    public static func clearAll(forGameMD5 md5: String, slotCount: Int = 4) {
        for port in 0..<slotCount {
            UserDefaults.standard.removeObject(forKey: udKey(md5: md5, port: port))
        }
    }

    private static func udKey(md5: String, port: Int) -> String {
        "\(keyPrefix).\(md5).port\(port)"
    }
}

// MARK: - Transfer Pak Config View

/// Configuration sheet for mounting GB/GBC ROMs into virtual Transfer Pak slots.
///
/// Show this view from the game context menu (before launch) or from the pause menu
/// (during emulation). When `liveCore` is provided, changes are applied immediately
/// via `TransferPakSupport` on the running core; otherwise they are stored in
/// `TransferPakStore` and applied the next time the game is loaded.
public struct TransferPakConfigView: View {
    /// The N64 game being configured.
    let game: PVGame
    /// Called to apply a slot change on the running core (optional hot-swap during play).
    /// Signature: `(port: Int, rom: TransferPakROM?) -> Void`
    var applyLiveSlotChange: ((Int, TransferPakROM?) -> Void)?
    /// Called when the view should dismiss (e.g. "Done" tapped).
    var onDismiss: (() -> Void)?

    private let slotCount: Int

    @State private var selectedPaths: [URL?]
    @State private var gbcGames: [PVGame] = []

    public init(game: PVGame,
                applyLiveSlotChange: ((Int, TransferPakROM?) -> Void)? = nil,
                onDismiss: (() -> Void)? = nil) {
        self.game = game.isFrozen ? game : game.freeze()
        self.applyLiveSlotChange = applyLiveSlotChange
        self.onDismiss = onDismiss

        let slots = 4
        self.slotCount = slots

        let md5 = game.md5Hash
        var paths: [URL?] = []
        for port in 0..<slots {
            paths.append(TransferPakStore.romPath(forGameMD5: md5, port: port))
        }
        _selectedPaths = State(initialValue: paths)
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            List {
                infoSection
                slotsSection
                clearSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Transfer Pak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyAndDismiss()
                    }
                }
            }
            .onAppear(perform: loadGBCGames)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Sections

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("What is the Transfer Pak?", systemImage: "info.circle.fill")
                    .font(.headline)
                Text("""
The Transfer Pak is an N64 controller accessory that lets you insert a \
Game Boy or Game Boy Color cartridge so the N64 game can read its save \
data or ROM.

Games like **Pokémon Stadium** and **Pokémon Stadium 2** use it to unlock \
Pokémon from your Game Boy save file. **Mario Tennis** uses it to transfer \
your Game Boy character.

Select the matching GB/GBC ROM for each controller port below. Only ports \
set to "Transfer Pak" in Core Settings will use these ROMs.
""")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var slotsSection: some View {
        Section {
            ForEach(0..<slotCount, id: \.self) { port in
                portRow(port: port)
            }
        } header: {
            Text("Controller Ports")
        } footer: {
            Text("To enable Transfer Pak on a port, open Core Settings and set that port\u{2019}s Controller Pak to \u{201C}Transfer Pak\u{201D}.")
                .font(.footnote)
        }
    }

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                clearAll()
            } label: {
                Label("Clear All Transfer Pak Slots", systemImage: "xmark.circle")
            }
        }
    }

    // MARK: - Port Row

    @ViewBuilder
    private func portRow(_ port: Int) -> some View {
        let selectedPath = selectedPaths[port]
        let romName = selectedPath.map { $0.deletingPathExtension().lastPathComponent } ?? "Not configured"

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label("Port \(port + 1)", systemImage: "gamecontroller")
                    .font(.body.weight(.medium))
                Spacer()
                Menu {
                    Button {
                        // No ROM
                        updateSlot(port: port, url: nil)
                    } label: {
                        if selectedPath == nil {
                            Label("None (selected)", systemImage: "checkmark")
                        } else {
                            Text("None")
                        }
                    }
                    Divider()
                    if gbcGames.isEmpty {
                        Text("No GB/GBC games found in library")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(gbcGames, id: \.md5Hash) { gbGame in
                            Button {
                                if let url = gbGame.file?.url {
                                    updateSlot(port: port, url: url)
                                }
                            } label: {
                                let isSelected = selectedPath != nil && selectedPath == gbGame.file?.url
                                if isSelected {
                                    Label(gbGame.title, systemImage: "checkmark")
                                } else {
                                    Text(gbGame.title)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            Text(romName)
                .font(.caption)
                .foregroundStyle(selectedPath == nil ? .tertiary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func updateSlot(port: Int, url: URL?) {
        selectedPaths[port] = url
        TransferPakStore.setRomPath(url, forGameMD5: game.md5Hash, port: port)
        if let apply = applyLiveSlotChange {
            let rom = url.map { TransferPakROM(romPath: $0) }
            apply(port, rom)
            DLOG("TransferPak: live-applied port \(port) → \(url?.lastPathComponent ?? "nil")")
        }
    }

    private func clearAll() {
        for port in 0..<slotCount {
            updateSlot(port: port, url: nil)
        }
    }

    private func applyAndDismiss() {
        onDismiss?()
    }

    // MARK: - Data Loading

    private func loadGBCGames() {
        Task { @MainActor in
            guard let realm = try? await Realm() else { return }
            // Find all GB and GBC games that have a local file
            let gbSystemIDs = ["com.provenance.gb", "com.provenance.gbc"]
            let games = realm.objects(PVGame.self)
                .filter("system.identifier IN %@ AND file != nil", gbSystemIDs)
                .sorted(byKeyPath: "title")
                .freeze()
            gbcGames = Array(games)
        }
    }
}

// MARK: - Known Transfer Pak Games

/// N64 game titles known to support (or require) the Transfer Pak.
/// Used to auto-prompt for Transfer Pak configuration at launch.
public enum TransferPakCompatibleGames {
    /// Known Transfer Pak titles keyed by common title substring (case-insensitive).
    /// Values describe the Transfer Pak feature in the game.
    public static let knownTitles: [(titleFragment: String, description: String)] = [
        // More specific (longer) fragments must come before shorter ones so that
        // `first(where:)` returns the most accurate match (e.g. "stadium 2" before "stadium").
        ("pokémon stadium 2",  "Supports GB/GBC Pokémon saves from Gold, Silver, Crystal, and Gen 1 games."),
        ("pokemon stadium 2",  "Supports GB/GBC Pokémon saves from Gold, Silver, Crystal, and Gen 1 games."),
        ("pokémon stadium",    "Transfer Pokémon from your Game Boy game to compete in stadium battles."),
        ("pokemon stadium",    "Transfer Pokémon from your Game Boy game to compete in stadium battles."),
        ("mario tennis",       "Transfer your character from the Game Boy Color Mario Tennis game."),
        ("mario golf",         "Transfer your character from the Game Boy Color Mario Golf game."),
        ("pokémon snap",       "Unlock GB Pokémon Printer functionality."),
        ("pokemon snap",       "Unlock GB Pokémon Printer functionality."),
        ("kirby tilt",         "Required: reads Kirby Tilt 'n' Tumble cartridge for GB sensor data."),
        ("hey you, pikachu",   "Transfer Pokémon to Pokémon Stadium 2 via GB Printer simulation."),
        ("perfect dark",       "Download and play GBC Perfect Dark via Transfer Pak."),
    ]

    /// Returns the Transfer Pak description if the game title is a known Transfer Pak title.
    public static func transferPakDescription(forTitle title: String) -> String? {
        let lower = title.lowercased()
        return knownTitles.first { lower.contains($0.titleFragment) }?.description
    }

    /// Returns `true` when the game is a known Transfer Pak title.
    public static func isKnownTransferPakGame(_ title: String) -> Bool {
        transferPakDescription(forTitle: title) != nil
    }
}

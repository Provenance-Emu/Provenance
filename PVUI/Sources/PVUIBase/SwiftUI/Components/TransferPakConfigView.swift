//
//  TransferPakConfigView.swift
//  PVUIBase
//
//  Part of #3027 — Transfer Pak UI for Mupen64Plus N64 cores
//  Closes #2739 — Transfer Pak slot assignment UI (pre-launch prompt)
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
//  Usage:
//   • Pre-launch (auto-prompt):  Set `launchAction` — shows "Skip & Launch" / "Launch Game"
//   • Context menu (pre-launch): Leave `launchAction` nil — shows "Done"
//   • Pause menu (in-session):   Set `applyLiveSlotChange` — hot-swaps ROMs live
//

import SwiftUI
import PVLibrary
import PVCoreBridge
import PVLogging
import RealmSwift

// MARK: - Transfer Pak persistent store

/// UserDefaults-backed storage for per-game Transfer Pak ROM selections.
///
/// Keys follow the pattern: `PVTransferPak.<n64md5>.port<0..3>` → GB game md5Hash string.
/// Storing the GB game's md5Hash (Realm primary key) rather than an absolute file path
/// keeps configured slots valid across ROM-directory changes (e.g. iCloud sync toggling).
public enum TransferPakStore {
    private static let keyPrefix = "PVTransferPak"

    /// Returns the URL of the GB/GBC ROM configured for the given N64 game and port,
    /// or `nil` if no game is configured or its file is not currently on disk.
    public static func romPath(forGameMD5 md5: String, port: Int) -> URL? {
        guard (0..<4).contains(port) else { return nil }
        let key = udKey(md5: md5, port: port)
        guard let storedMD5 = UserDefaults.standard.string(forKey: key) else { return nil }
        // Resolve the stored GB game md5Hash to its current on-disk URL via Realm.
        guard let realm = try? Realm(),
              let gbGame = realm.object(ofType: PVGame.self, forPrimaryKey: storedMD5),
              !gbGame.isInvalidated,
              let url = gbGame.file?.url,
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    /// Stores the GB/GBC game's md5Hash for the given N64 game and controller port.
    /// Pass `nil` to clear the slot.
    public static func setGBGame(_ gbGameMD5: String?, forGameMD5 md5: String, port: Int) {
        guard (0..<4).contains(port) else { return }
        let key = udKey(md5: md5, port: port)
        if let gbGameMD5 {
            UserDefaults.standard.set(gbGameMD5, forKey: key)
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

    // MARK: - Skip tracking

    /// Marks that the user has explicitly dismissed the pre-launch Transfer Pak prompt
    /// for this game without configuring any slots (tapped "Skip & Launch").
    /// The prompt is then suppressed on future launches so it doesn't nag the user.
    public static func markPromptSkipped(forGameMD5 md5: String) {
        UserDefaults.standard.set(true, forKey: skipKey(md5: md5))
    }

    /// Returns `true` if the user has previously skipped the pre-launch Transfer Pak
    /// prompt for this game and no slots are currently configured.
    public static func wasPromptSkipped(forGameMD5 md5: String) -> Bool {
        UserDefaults.standard.bool(forKey: skipKey(md5: md5))
    }

    /// Clears the skip flag — e.g. when the user later configures a slot via the pause menu.
    public static func clearSkipFlag(forGameMD5 md5: String) {
        UserDefaults.standard.removeObject(forKey: skipKey(md5: md5))
    }

    private static func skipKey(md5: String) -> String {
        "\(keyPrefix).\(md5).skippedPrompt"
    }

    private static func udKey(md5: String, port: Int) -> String {
        "\(keyPrefix).\(md5).port\(port)"
    }
}

// MARK: - Transfer Pak Config View

/// Configuration sheet for mounting GB/GBC ROMs into virtual Transfer Pak slots.
///
/// Three presentation modes:
///  1. **Pre-launch auto-prompt** — set `launchAction`; toolbar shows "Skip & Launch" and "Launch Game"
///  2. **Context menu (pre-launch)** — leave `launchAction` nil; toolbar shows "Done"
///  3. **Pause menu (in-session)** — set `applyLiveSlotChange`; changes are applied live
///
/// When `applyLiveSlotChange` is provided, changes are applied immediately via
/// `TransferPakSupport` on the running core; otherwise they are stored in `TransferPakStore`
/// and applied the next time the game is loaded via
/// `PVEmulatorViewController.applyPersistedTransferPakIfNeeded()`.
public struct TransferPakConfigView: View {
    /// The N64 game being configured.
    let game: PVGame
    /// Called to apply a slot change on the running core (optional hot-swap during play).
    /// Signature: `(port: Int, rom: TransferPakROM?) -> Void`
    var applyLiveSlotChange: ((Int, TransferPakROM?) -> Void)?
    /// When non-nil, the toolbar shows "Skip & Launch" / "Launch Game" buttons instead of "Done".
    /// Called when user taps "Skip & Launch" (no configuration) or "Launch Game" (after configuring).
    var launchAction: (() -> Void)?
    /// Called when the view should dismiss (e.g. "Done" tapped).
    var onDismiss: (() -> Void)?

    private let slotCount: Int

    @State private var selectedPaths: [URL?]
    /// MD5 hashes buffered per port in pre-launch mode (nil = clear the slot).
    /// Only ports where `slotIsStaged[port] == true` are committed on "Launch Game".
    @State private var stagedMD5s: [String?]
    /// Tracks which ports the user has explicitly modified during this pre-launch session.
    @State private var slotIsStaged: [Bool]
    @State private var gbAndGbcGames: [PVGame] = []
    @State private var noGBGamesInLibrary: Bool = false

    public init(game: PVGame,
                slotCount: Int = 4,
                applyLiveSlotChange: ((Int, TransferPakROM?) -> Void)? = nil,
                launchAction: (() -> Void)? = nil,
                onDismiss: (() -> Void)? = nil) {
        self.game = game.isFrozen ? game : game.freeze()
        self.applyLiveSlotChange = applyLiveSlotChange
        self.launchAction = launchAction
        self.onDismiss = onDismiss
        self.slotCount = min(4, max(1, slotCount))

        // Start with empty slots; real Realm resolution happens in onAppear to
        // avoid synchronous Realm access during view construction (often on main thread).
        _selectedPaths = State(initialValue: Array(repeating: nil, count: self.slotCount))
        _stagedMD5s = State(initialValue: Array(repeating: nil, count: self.slotCount))
        _slotIsStaged = State(initialValue: Array(repeating: false, count: self.slotCount))
    }

    // MARK: - Computed Helpers

    private var n64Title: String { game.title }

    /// Games from the library that are suggested for this particular N64 title.
    private var suggestedGames: [PVGame] {
        guard !gbAndGbcGames.isEmpty else { return [] }
        let fragments = TransferPakCompatibleGames.suggestedGBTitleFragments(forN64Title: n64Title)
        guard !fragments.isEmpty else { return [] }
        return gbAndGbcGames.filter { gbGame in
            let lower = gbGame.title.lowercased()
            return fragments.contains { lower.contains($0) }
        }
    }

    private var otherGames: [PVGame] {
        let suggestedMD5s = Set(suggestedGames.map { $0.md5Hash })
        return gbAndGbcGames.filter { !suggestedMD5s.contains($0.md5Hash) }
    }

    private var configuredSlotCount: Int {
        selectedPaths.filter { $0 != nil }.count
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                // Retrowave background
                Color.retroBlack.ignoresSafeArea()
                RetroGrid(lineSpacing: 28, lineColor: Color.retroPurple.opacity(0.25))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerSection
                        if noGBGamesInLibrary {
                            noGamesWarning
                        } else {
                            slotsCard
                            clearButton
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    RetroGlowText("TRANSFER PAK", fontSize: 16)
                }
                if let launchAction {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip & Launch") {
                            // Record that the user deliberately skipped so we don't nag again.
                            let md5 = game.md5Hash
                            Task.detached(priority: .utility) {
                                TransferPakStore.markPromptSkipped(forGameMD5: md5)
                            }
                            launchAction()
                        }
                        .foregroundStyle(Color.retroBlue)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Launch Game") {
                            commitStagedSlots()
                            launchAction()
                        }
                        .bold()
                        .foregroundStyle(Color.retroPink)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            applyAndDismiss()
                        }
                        .foregroundStyle(Color.retroPink)
                    }
                }
            }
            .toolbarBackground(Color.retroBlack.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                loadSelectedPaths()
                loadGBAndGbcGames()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Game-specific Transfer Pak description
            if let desc = TransferPakCompatibleGames.transferPakDescription(forTitle: n64Title) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.retroBlue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(n64Title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.retroYellow)
                        Text(desc)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.retroDarkBlue.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.retroBlue.opacity(0.5), lineWidth: 1)
                        )
                )
            } else {
                // Generic info for unlisted games
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.retroBlue)
                        .font(.title3)
                    Text("Select which Game Boy or Game Boy Color cartridge to insert into each controller's Transfer Pak slot.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.retroDarkBlue.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.retroBlue.opacity(0.5), lineWidth: 1)
                        )
                )
            }

        }
    }

    // MARK: - No GB Games Warning

    private var noGamesWarning: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.retroPink)
                .shadow(color: Color.retroPink.opacity(0.6), radius: 8)

            Text("No Game Boy ROMs Found")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Import your Game Boy or Game Boy Color ROMs into the Provenance library first. Once imported, return here to configure the Transfer Pak.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroDarkBlue.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.retroPink.opacity(0.4), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.retroPink.opacity(0.2), radius: 12)
    }

    // MARK: - Slots Card

    private var slotsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(Color.retroPink)
                Text("CONTROLLER PORTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.retroPink)
                Spacer()
                if configuredSlotCount > 0 {
                    Text("\(configuredSlotCount) configured")
                        .font(.caption2)
                        .foregroundStyle(Color.retroGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.retroGreen.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(Color.retroGreen.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .background(Color.retroPurple.opacity(0.4))

            ForEach(0..<slotCount, id: \.self) { port in
                portRow(port: port)
                if port < slotCount - 1 {
                    Divider()
                        .background(Color.retroPurple.opacity(0.2))
                        .padding(.horizontal, 14)
                }
            }

            // Footer note
            Text("Assigning a game automatically sets that port to Transfer Pak mode. You can also adjust pak types manually via Core Settings.")
                .font(.caption2)
                .foregroundStyle(Color.retroBlue.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroDarkBlue.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.retroPurple.opacity(0.6), Color.retroBlue.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color.retroPurple.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    // MARK: - Port Row

    @ViewBuilder
    private func portRow(port: Int) -> some View {
        let selectedPath = selectedPaths[port]
        let romName = selectedPath.map { $0.deletingPathExtension().lastPathComponent } ?? "Empty"
        let isConfigured = selectedPath != nil

        HStack(spacing: 12) {
            // Port indicator
            ZStack {
                Circle()
                    .fill(isConfigured ? Color.retroPink.opacity(0.2) : Color.retroDarkBlue.opacity(0.5))
                    .overlay(Circle().strokeBorder(isConfigured ? Color.retroPink : Color.retroPurple.opacity(0.4), lineWidth: 1.5))
                    .frame(width: 36, height: 36)
                Text("\(port + 1)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(isConfigured ? Color.retroPink : Color.white.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Controller \(port + 1)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    if isConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.retroGreen)
                    }
                    Text(romName)
                        .font(.caption)
                        .foregroundStyle(isConfigured ? Color.retroGreen : Color.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // Game picker menu
            Menu {
                Button {
                    updateSlot(port: port, gbGame: nil)
                } label: {
                    if selectedPath == nil {
                        Label("Empty (current)", systemImage: "checkmark")
                    } else {
                        Label("Clear Slot", systemImage: "xmark")
                    }
                }

                if !suggestedGames.isEmpty {
                    Divider()
                    SwiftUI.Section("Suggested for \(n64Title)") {
                        ForEach(suggestedGames, id: \.md5Hash) { gbGame in
                            Button {
                                updateSlot(port: port, gbGame: gbGame)
                            } label: {
                                let isSel = selectedPath != nil && selectedPath == gbGame.file?.url
                                if isSel {
                                    Label(gbGame.title, systemImage: "checkmark")
                                } else {
                                    Label(gbGame.title, systemImage: "star.fill")
                                }
                            }
                        }
                    }
                }

                if !otherGames.isEmpty {
                    Divider()
                    if !suggestedGames.isEmpty {
                        SwiftUI.Section("Other GB/GBC Games") {
                            ForEach(otherGames, id: \.md5Hash) { gbGame in
                                Button {
                                    updateSlot(port: port, gbGame: gbGame)
                                } label: {
                                    let isSel = selectedPath != nil && selectedPath == gbGame.file?.url
                                    if isSel {
                                        Label(gbGame.title, systemImage: "checkmark")
                                    } else {
                                        Text(gbGame.title)
                                    }
                                }
                            }
                        }
                    } else {
                        ForEach(otherGames, id: \.md5Hash) { gbGame in
                            Button {
                                updateSlot(port: port, gbGame: gbGame)
                            } label: {
                                let isSel = selectedPath != nil && selectedPath == gbGame.file?.url
                                if isSel {
                                    Label(gbGame.title, systemImage: "checkmark")
                                } else {
                                    Text(gbGame.title)
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isConfigured ? "Change" : "Select")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(Color.retroBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.retroBlue.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.retroBlue.opacity(0.4), lineWidth: 1))
                )
            }
            .accessibilityLabel("Select Transfer Pak cartridge for port \(port + 1)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Clear Button

    private var clearButton: some View {
        Button(role: .destructive) {
            clearAll()
        } label: {
            HStack {
                Image(systemName: "xmark.circle")
                    .font(.body)
                Text("Clear All Transfer Pak Slots")
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(Color.retroPink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.retroPink.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.retroPink.opacity(0.35), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Actions

    private func updateSlot(port: Int, gbGame: PVGame?) {
        let url = gbGame?.file?.url
        selectedPaths[port] = url
        if launchAction != nil {
            // Pre-launch mode: buffer the change without persisting to UserDefaults.
            // Pak type is also deferred — it will be committed in commitStagedSlots() so
            // that tapping "Skip & Launch" does not leave ports in Transfer Pak mode with
            // no ROM configured.
            stagedMD5s[port] = gbGame?.md5Hash
            slotIsStaged[port] = true
        } else {
            TransferPakStore.setGBGame(gbGame?.md5Hash, forGameMD5: game.md5Hash, port: port)
            if let apply = applyLiveSlotChange {
                let rom = url.map { TransferPakROM(romPath: $0) }
                apply(port, rom)
                DLOG("TransferPak: live-applied port \(port) → \(url?.lastPathComponent ?? "nil")")
            }
            // Auto-set or clear pak type immediately in live/done modes.
            autoUpdatePakType(port: port + 1, assignedGame: gbGame)
        }
        // If the user is actively configuring a slot, clear the "skipped" flag so future
        // launches can offer the prompt again if they later clear all slots.
        if gbGame != nil {
            let md5 = game.md5Hash
            Task.detached(priority: .utility) {
                TransferPakStore.clearSkipFlag(forGameMD5: md5)
            }
        }
    }

    /// Automatically switches the controller pak setting so the user doesn't have to visit
    /// Core Settings separately. When a GB game is assigned, the port is switched to Transfer Pak.
    /// When cleared, the port falls back to Auto (ROM database default).
    private func autoUpdatePakType(port: Int, assignedGame: PVGame?) {
        let gameMD5 = game.md5Hash.isEmpty ? nil : game.md5Hash
        let newType: N64PakType = assignedGame != nil ? .transferPak : .auto
        N64PakStore.setPakType(newType, forPort: port, gameMD5: gameMD5)
        DLOG("TransferPak: auto-set port \(port) pak type → \(newType.title)")
    }

    /// Persists staged slot changes to UserDefaults. Called when user taps "Launch Game".
    /// Also commits pak type changes so that ports are only set to Transfer Pak mode
    /// when the user actually confirms via "Launch Game" (not on "Skip & Launch").
    private func commitStagedSlots() {
        let gameMD5 = game.md5Hash.isEmpty ? nil : game.md5Hash
        for port in 0..<slotCount where slotIsStaged[port] {
            TransferPakStore.setGBGame(stagedMD5s[port], forGameMD5: game.md5Hash, port: port)
            let newType: N64PakType = stagedMD5s[port] != nil ? .transferPak : .auto
            N64PakStore.setPakType(newType, forPort: port + 1, gameMD5: gameMD5)
            DLOG("TransferPak: committed port \(port + 1) → \(newType.title)")
        }
    }

    private func clearAll() {
        for port in 0..<slotCount {
            updateSlot(port: port, gbGame: nil)
        }
        // Reset the skip flag whenever the user explicitly clears all slots.
        // Without this, a previously-skipped game that has been fully cleared would
        // never show the pre-launch prompt again, even though the user has now wiped
        // their config and would benefit from seeing it next time they launch.
        let md5 = game.md5Hash
        Task.detached(priority: .utility) {
            TransferPakStore.clearSkipFlag(forGameMD5: md5)
        }
    }

    private func applyAndDismiss() {
        onDismiss?()
    }

    // MARK: - Data Loading

    private func loadSelectedPaths() {
        let md5 = game.md5Hash
        let slots = slotCount
        Task.detached(priority: .userInitiated) {
            var paths: [URL?] = []
            for port in 0..<slots {
                paths.append(TransferPakStore.romPath(forGameMD5: md5, port: port))
            }
            await MainActor.run { selectedPaths = paths }
        }
    }

    private func loadGBAndGbcGames() {
        Task.detached(priority: .userInitiated) {
            let frozen = Self.readGBAndGbcGamesFromCurrentThreadRealm()
            await MainActor.run {
                gbAndGbcGames = frozen
                noGBGamesInLibrary = frozen.isEmpty
            }
        }
    }

    private static func readGBAndGbcGamesFromCurrentThreadRealm() -> [PVGame] {
        guard let realm = try? Realm() else { return [] }
        let gbSystemIDs = [SystemIdentifier.GB.rawValue, SystemIdentifier.GBC.rawValue]
        let games = realm.objects(PVGame.self)
            .filter("systemIdentifier IN %@ AND file != nil AND isDownloaded == true", gbSystemIDs)
            .sorted(byKeyPath: "title")
            .freeze()
        return Array(games)
    }
}

// MARK: - Known Transfer Pak Games

/// N64 game titles known to support (or require) the Transfer Pak.
/// Used to auto-prompt for Transfer Pak configuration at launch.
public enum TransferPakCompatibleGames {
    /// Known Transfer Pak titles keyed by common title substring (case-insensitive).
    /// Values describe the Transfer Pak feature in the game.
    public static let knownTitles: [(titleFragment: String, description: String)] = [
        ("pokémon stadium 2",  "Transfer Pokémon from Gold, Silver, Crystal, Red, Blue, or Yellow via Transfer Pak."),
        ("pokemon stadium 2",  "Transfer Pokémon from Gold, Silver, Crystal, Red, Blue, or Yellow via Transfer Pak."),
        ("pokémon stadium",    "Insert your Pokémon Red, Blue, or Yellow cartridge to use your own Pokémon in stadium battles."),
        ("pokemon stadium",    "Insert your Pokémon Red, Blue, or Yellow cartridge to use your own Pokémon in stadium battles."),
        ("mario tennis",       "Transfer your character from the Game Boy Color Mario Tennis game."),
        ("mario golf",         "Transfer your character from the Game Boy Color Mario Golf game."),
        ("pokémon snap",       "Unlock GB Pokémon Printer functionality."),
        ("pokemon snap",       "Unlock GB Pokémon Printer functionality."),
        ("kirby tilt",         "Required: reads the Kirby Tilt 'n' Tumble cartridge for its built-in tilt sensor."),
        ("perfect dark",       "Download and play the GBC version of Perfect Dark via Transfer Pak."),
    ]

    /// Maps N64 title fragments to expected Game Boy game title substrings for smart suggestions.
    public static let suggestedGBTitles: [(n64Fragment: String, gbFragments: [String])] = [
        ("pokemon stadium 2",  ["pokemon gold", "pokemon silver", "pokemon crystal", "pokemon red", "pokemon blue", "pokemon yellow", "pokémon gold", "pokémon silver", "pokémon crystal", "pokémon red", "pokémon blue", "pokémon yellow"]),
        ("pokémon stadium 2",  ["pokemon gold", "pokemon silver", "pokemon crystal", "pokemon red", "pokemon blue", "pokemon yellow", "pokémon gold", "pokémon silver", "pokémon crystal", "pokémon red", "pokémon blue", "pokémon yellow"]),
        ("pokemon stadium",    ["pokemon red", "pokemon blue", "pokemon yellow", "pokémon red", "pokémon blue", "pokémon yellow"]),
        ("pokémon stadium",    ["pokemon red", "pokemon blue", "pokemon yellow", "pokémon red", "pokémon blue", "pokémon yellow"]),
        ("mario tennis",       ["mario tennis"]),
        ("mario golf",         ["mario golf"]),
        ("pokemon snap",       ["pokemon", "pokémon"]),
        ("pokémon snap",       ["pokemon", "pokémon"]),
        ("kirby tilt",         ["kirby tilt"]),
        ("perfect dark",       ["perfect dark"]),
    ]

    /// Returns the Transfer Pak description if the game title is a known Transfer Pak title.
    public static func transferPakDescription(forTitle title: String) -> String? {
        let lower = title.lowercased()
        let matches = knownTitles.filter { lower.contains($0.titleFragment) }
        guard !matches.isEmpty else { return nil }
        return matches.max(by: { $0.titleFragment.count < $1.titleFragment.count })?.description
    }

    /// Returns `true` when the game is a known Transfer Pak title.
    public static func isKnownTransferPakGame(_ title: String) -> Bool {
        transferPakDescription(forTitle: title) != nil
    }

    /// Returns GB game title substrings to suggest for a given N64 game title.
    /// Used to highlight matching GB library games in the picker.
    public static func suggestedGBTitleFragments(forN64Title title: String) -> [String] {
        let lower = title.lowercased()
        for entry in suggestedGBTitles where lower.contains(entry.n64Fragment) {
            return entry.gbFragments
        }
        return []
    }
}

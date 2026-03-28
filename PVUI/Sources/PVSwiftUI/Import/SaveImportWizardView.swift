//
//  SaveImportWizardView.swift
//  PVUI / PVSwiftUI
//
//  Created by Agent on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Multi-step save import wizard with retrowave neon styling.
//  Part of issue #3555 (Save Import UI with game-matching, progress tracking & retrowave theme).
//

import SwiftUI
import UniformTypeIdentifiers
import PVLibrary
import PVRealm
import PVLogging
import PVUIBase

// MARK: - WizardStep

private enum WizardStep {
    case fileSelection
    case gameMatching
    case summary
    case progress
    case done
}

// MARK: - ImportOutcome

private enum ImportOutcome {
    case success
    case failure(String)
}

// MARK: - SaveImportWizardView

/// Multi-step import wizard for save bundles and battery save files.
///
/// **Entry points:**
/// - `Settings → Library → Import Saves` — no pre-selected file or game.
/// - `Game context menu → Import Save` — pass `preSelectedGame` to skip matching.
///
/// **tvOS:** The file-selection step shows a CloudKit/iCloud Drive guidance message instead
/// of a document picker (unavailable on Apple TV). All other steps work identically.
public struct SaveImportWizardView: View {

    // MARK: - Init

    let preSelectedGame: PVGame?

    public init(preSelectedGame: PVGame? = nil) {
        self.preSelectedGame = preSelectedGame
    }

    // MARK: - State

    @Environment(\.dismiss) private var dismiss

    @State private var step: WizardStep = .fileSelection
    @State private var selectedURL: URL?
    @State private var matchResult: SaveImportMatchResult?
    @State private var confirmedGame: PVGame?
    @State private var isMatching = false
    @State private var importProgress: Double = 0
    @State private var outcome: ImportOutcome?
    @State private var allGames: [PVGame] = []
    @State private var showGamePicker = false

    #if !os(tvOS)
    @State private var showFileImporter = false
    #endif

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                    .ignoresSafeArea()

                stepContent
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(navigationTitle)
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .progress {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.retroPink)
                    }
                }
            }
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleFileImporterResult
        )
        #endif
        .sheet(isPresented: $showGamePicker) {
            GamePickerView(games: allGames) { picked in
                confirmedGame = picked.isFrozen ? picked : picked.freeze()
                showGamePicker = false
                if step == .gameMatching {
                    step = .summary
                }
            }
        }
        .onAppear(perform: setup)
    }

    // MARK: - Setup

    private func setup() {
        if let pre = preSelectedGame {
            let frozen = pre.isFrozen ? pre : pre.freeze()
            confirmedGame = frozen
            matchResult = SaveImportMatchResult(game: frozen, confidence: .exact)
        }
        loadAllGames()
    }

    // MARK: - Allowed file types

    private var allowedContentTypes: [UTType] {
        var types: [UTType] = [.zip, .data]
        if let t = UTType(filenameExtension: "pvsave") { types.append(t) }
        if let t = UTType(filenameExtension: "sav") { types.append(t) }
        if let t = UTType(filenameExtension: "srm") { types.append(t) }
        if let t = UTType(filenameExtension: "ram") { types.append(t) }
        return types
    }

    // MARK: - Navigation title

    private var navigationTitle: String {
        switch step {
        case .fileSelection: return "Import Save"
        case .gameMatching:  return "Match Game"
        case .summary:       return "Confirm Import"
        case .progress:      return "Importing…"
        case .done:          return "Done"
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Color.retroBlack
            RetroGrid(lineColor: .retroPink.opacity(0.07))
        }
    }

    // MARK: - Gradient

    private var neonGradient: LinearGradient {
        LinearGradient(
            colors: [.retroPink, .retroPurple, .retroBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Step router

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .fileSelection: fileSelectionStep
        case .gameMatching:  gameMatchingStep
        case .summary:       summaryStep
        case .progress:      progressStep
        case .done:          doneStep
        }
    }

    // MARK: - Step 1: File Selection

    private var fileSelectionStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 72))
                .foregroundStyle(neonGradient)
                .shadow(color: .retroPink, radius: 14)

            VStack(spacing: 10) {
                Text("IMPORT SAVE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(neonGradient)

                Text("Choose a .zip save bundle or a battery save file (.sav, .srm, .ram) to import.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            #if !os(tvOS)
            Button { showFileImporter = true } label: {
                Label("Choose File", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(SaveImportNeonButtonStyle(color: .retroPink))
            #else
            tvOSNoPickerHint
            #endif

            Spacer()
        }
    }

    #if os(tvOS)
    private var tvOSNoPickerHint: some View {
        VStack(spacing: 14) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 44))
                .foregroundColor(.retroBlue)
                .shadow(color: .retroBlue, radius: 10)

            Text("On Apple TV, saves arrive via iCloud Drive sync. Enable iCloud sync in Cloud Settings and share a save bundle from another device to import it here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(20)
        .background(Color.retroBlue.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.retroBlue.opacity(0.3), lineWidth: 1)
        )
    }
    #endif

    // MARK: - Step 2: Game Matching

    private var gameMatchingStep: some View {
        VStack(spacing: 28) {
            Spacer()

            if isMatching {
                VStack(spacing: 18) {
                    ProgressView()
                        .tint(.retroPink)
                        .scaleEffect(1.6)
                        .shadow(color: .retroPink, radius: 10)
                    Text("Finding matching game…")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
            } else if let result = matchResult {
                gameMatchContent(result)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func gameMatchContent(_ result: SaveImportMatchResult) -> some View {
        VStack(spacing: 22) {
            // Confidence badge
            Label(confidenceText(result.confidence),
                  systemImage: confidenceIcon(result.confidence))
                .font(.caption.bold())
                .foregroundColor(confidenceColor(result.confidence))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(confidenceColor(result.confidence).opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(confidenceColor(result.confidence).opacity(0.4), lineWidth: 1)
                )

            // Game card
            VStack(spacing: 10) {
                if let game = confirmedGame ?? result.game {
                    Text(game.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .retroPink, radius: 5)
                    Text(game.systemIdentifier)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.4))
                    Text("No matching game found")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(Color.retroPurple.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.retroPurple.opacity(0.55), lineWidth: 1)
                    .shadow(color: .retroPurple, radius: 8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Action buttons
            VStack(spacing: 12) {
                if confirmedGame != nil || result.game != nil {
                    Button {
                        step = .summary
                    } label: {
                        Label("Use This Game", systemImage: "checkmark.circle")
                            .font(.headline)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(SaveImportNeonButtonStyle(color: .retroGreen))
                }

                Button {
                    showGamePicker = true
                } label: {
                    Label(confirmedGame == nil && result.game == nil ? "Select Game" : "Choose Different Game",
                          systemImage: "list.bullet")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 12)
                }
                .buttonStyle(SaveImportNeonButtonStyle(color: .retroBlue, filled: false))
            }
        }
    }

    // MARK: - Step 3: Summary

    private var summaryStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(neonGradient)
                .shadow(color: .retroBlue, radius: 14)

            if let game = confirmedGame {
                VStack(spacing: 6) {
                    Text("Ready to import saves for")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    Text(game.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .retroPink, radius: 4)
                }
            }

            if let url = selectedURL {
                summaryCard(url: url)
            }

            if let game = confirmedGame, game.saveStates.count > 0 {
                overwriteWarning(count: game.saveStates.count)
            }

            Button {
                performImport()
            } label: {
                Label("Import Now", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(SaveImportNeonButtonStyle(color: .retroPink))

            Spacer()
        }
    }

    private func summaryCard(url: URL) -> some View {
        let ext = url.pathExtension.lowercased()
        let typeLabel = (ext == "zip" || ext == "pvsave") ? "Save Bundle (.zip)" : "Battery Save (.\(ext))"
        let typeIcon = (ext == "zip" || ext == "pvsave") ? "archivebox.fill" : "memorychip"

        return VStack(alignment: .leading, spacing: 12) {
            summaryRow(icon: "doc.fill", label: "File", value: url.lastPathComponent)
            summaryRow(icon: typeIcon, label: "Type", value: typeLabel)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.retroDarkBlue.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.retroBlue.opacity(0.3), lineWidth: 1)
        )
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.retroBlue)
                .frame(width: 18)
            Text(label + ":")
                .foregroundColor(.white.opacity(0.5))
                .font(.subheadline)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.subheadline.bold())
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func overwriteWarning(count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.retroYellow)
            Text("This game has \(count) existing save state\(count == 1 ? "" : "s"). Importing may overwrite matching files.")
                .font(.caption)
                .foregroundColor(.retroYellow)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color.retroYellow.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.retroYellow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Step 4: Progress

    private var progressStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(neonGradient)
                .shadow(color: .retroPink, radius: 18)

            Text("IMPORTING…")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(neonGradient)

            RetroProgressBar(progress: importProgress)
                .frame(height: 12)
                .padding(.horizontal, 32)
                .shadow(color: .retroPink.opacity(0.5), radius: 8)

            Text("\(Int(importProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.55))

            Spacer()
        }
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Group {
                switch outcome {
                case .success:
                    successView
                case .failure(let msg):
                    failureView(message: msg)
                case nil:
                    EmptyView()
                }
            }

            Button("Done") { dismiss() }
                .font(.headline)
                .frame(maxWidth: 200)
                .padding(.vertical, 14)
                .buttonStyle(SaveImportNeonButtonStyle(color: .retroPink))

            Spacer()
        }
    }

    private var successView: some View {
        VStack(spacing: 18) {
            glowCircle(icon: "checkmark.circle.fill", color: .retroGreen)

            Text("IMPORT COMPLETE")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(neonGradient)

            Text("Saves restored successfully.\nThey will appear after a library refresh or app relaunch.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 18) {
            glowCircle(icon: "xmark.circle.fill", color: .red)

            Text("IMPORT FAILED")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.red)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.red.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func glowCircle(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 110, height: 110)
                .shadow(color: color, radius: 26)
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(color)
                .shadow(color: color, radius: 16)
        }
    }

    // MARK: - Confidence helpers

    private func confidenceText(_ c: MatchConfidence) -> String {
        switch c {
        case .exact:    return "Exact Match"
        case .probable: return "Probable Match"
        case .manual:   return "Manual Selection"
        }
    }

    private func confidenceIcon(_ c: MatchConfidence) -> String {
        switch c {
        case .exact:    return "checkmark.seal.fill"
        case .probable: return "questionmark.circle.fill"
        case .manual:   return "hand.point.up.left.fill"
        }
    }

    private func confidenceColor(_ c: MatchConfidence) -> Color {
        switch c {
        case .exact:    return .retroGreen
        case .probable: return .retroYellow
        case .manual:   return .retroBlue
        }
    }

    // MARK: - File importer handler (non-tvOS)

    #if !os(tvOS)
    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            ELOG("SaveImportWizard: file importer error: \(error.localizedDescription)")
        case .success(let urls):
            guard let url = urls.first else { return }
            copyAndProceed(from: url)
        }
    }

    private func copyAndProceed(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            WLOG("SaveImportWizard: cannot access security-scoped resource: \(url.lastPathComponent)")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("PVSaveImportWizard_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            let dest = tmpDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: dest)
            selectedURL = dest
        } catch {
            ELOG("SaveImportWizard: failed to copy file: \(error.localizedDescription)")
            selectedURL = url
        }

        if preSelectedGame != nil {
            step = .summary
        } else {
            step = .gameMatching
            runMatching()
        }
    }
    #endif

    // MARK: - Async matching

    private func runMatching() {
        guard let url = selectedURL else { return }
        isMatching = true
        Task { @MainActor in
            let result = await SaveImportMatchingService.shared.match(bundleURL: url)
            matchResult = result
            confirmedGame = result.game
            isMatching = false
        }
    }

    // MARK: - Import execution

    private func performImport() {
        guard let url = selectedURL, let game = confirmedGame else { return }
        step = .progress
        importProgress = 0.1

        Task { @MainActor in
            let frozenGame = game.isFrozen ? game : game.freeze()
            importProgress = 0.35

            do {
                let ext = url.pathExtension.lowercased()
                if ext == "zip" || ext == "pvsave" {
                    importProgress = 0.5
                    try await SaveExporter.shared.importSaves(from: url, for: frozenGame)
                } else {
                    importProgress = 0.5
                    try await SaveExporter.shared.importSRAM(from: url, for: frozenGame)
                }
                importProgress = 1.0
                try? await Task.sleep(nanoseconds: 400_000_000)
                outcome = .success
            } catch {
                outcome = .failure(error.localizedDescription)
            }

            step = .done
            cleanupTempFile(url)
        }
    }

    private func cleanupTempFile(_ url: URL) {
        let parent = url.deletingLastPathComponent()
        guard parent.lastPathComponent.hasPrefix("PVSaveImportWizard_") else { return }
        try? FileManager.default.removeItem(at: parent)
    }

    // MARK: - Data loading

    private func loadAllGames() {
        // Realm access must happen on the main thread; freeze objects for safe cross-thread use.
        Task { @MainActor in
            allGames = PVGame.all.toArray().map { $0.isFrozen ? $0 : $0.freeze() }
        }
    }
}

// MARK: - SaveImportNeonButtonStyle

/// Retrowave neon button: filled or outlined, with neon glow shadow.
struct SaveImportNeonButtonStyle: ButtonStyle {
    let color: Color
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(filled ? .white : color)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(filled ? color : color.opacity(0.08))
                    .shadow(
                        color: color.opacity(configuration.isPressed ? 0.25 : 0.55),
                        radius: configuration.isPressed ? 4 : 12
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - GamePickerView

/// Searchable list of all library games for manual selection in the wizard.
private struct GamePickerView: View {
    let games: [PVGame]
    let onSelect: (PVGame) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [PVGame] {
        let sorted = games.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        let q = searchText.lowercased()
        return sorted.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.md5Hash) { game in
                    Button {
                        onSelect(game)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(game.title)
                                .foregroundColor(.primary)
                                .font(.body)
                            Text(game.systemIdentifier)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search games…")
            .navigationTitle("Select Game")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
